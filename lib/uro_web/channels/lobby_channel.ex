defmodule UroWeb.LobbyChannel do
  @moduledoc """
  ```mermaid
  stateDiagram
      [*] --> Connecting: Client connects to WebSocket
      Connecting --> Joining: Client sends JOIN message
      Joining --> LobbyAssigned: Server assigns or confirms lobby
      LobbyAssigned --> Identified: Server sends ID message with client ID
      Identified --> PeerConnected: Server notifies new peer connection with PEER_CONNECT message
      PeerConnected --> PeerDisconnected: Server notifies peer disconnection with PEER_DISCONNECT message
      PeerConnected --> OfferSent: Client sends OFFER message
      OfferSent --> AnswerReceived: Destination peer receives OFFER and sends ANSWER message
      AnswerReceived --> CandidateGenerated: Client generates CANDIDATE message
      CandidateGenerated --> Sealed: Client sends SEAL message to seal the lobby
      Sealed --> [*]: Lobby is sealed, no new clients can join, and lobby will be destroyed after 10 seconds
  ```

  ### Signaling Protocol

  | Type | Name            | Description                                                                                                                                                                                                 |
  |------|-----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
  | 0    | JOIN            | Must be sent by client immediately after connection to get a lobby assigned or join a known one (via the `data` field). This message is also sent by server back to the client to notify the assigned lobby, or simply a successful join.           |
  | 1    | ID              | Sent by server to identify the client when it joins a room (the `id` field will contain the assigned ID).                                                                                                                                          |
  | 2    | PEER_CONNECT    | Sent by server to notify new peers in the same lobby (the `id` field will contain the ID of the new peer).                                                                                                                                         |
  | 3    | PEER_DISCONNECT | Sent by server to notify when a peer in the same lobby disconnects (the `id` field will contain the ID of the disconnected peer).                                                                                                                  |
  | 4    | OFFER           | Sent by the client when creating a WebRTC offer then relayed back by the server to the destination peer.                                                                                                                                           |
  | 5    | ANSWER          | Sent by the client when creating a WebRTC answer then relayed back by the server to the destination peer.                                                                                                                                          |
  | 6    | CANDIDATE       | Sent by the client when generating new WebRTC candidates then relayed back by the server to the destination peer.                                                                                                                                  |
  | 7    | SEAL            | Sent by client to seal the lobby (only the client that created it is allowed to seal a lobby), and then back by the server to notify success. When a lobby is sealed, no new client will be able to join, and the lobby will be destroyed (and clients disconnected) after 10 seconds. |

  ### Message Fields

  - `id`: `number` - Represents a connected peer or `0`.
  - `type`: `number` - Represents the message type.
  - `data`: `string` - Contains the message-specific data.

  ### Example websocat

  ```bash
  websocat "ws://localhost:4000/socket/websocket"
  {"topic":"lobby:test_lobby","event":"phx_join","payload":{},"ref":1}
  {"topic":"lobby:test_lobby","event":"join","payload":{"data":"test_lobby"},"ref":2}
  {"topic":"lobby:test_lobby","event":"join","payload":{"data":"test_lobby"},"ref":3}
  {"topic":"lobby:test_lobby","event":"offer","payload":{"id":"test_user","type":4,"data":"offer_data"},"ref":7}
  {"topic":"lobby:test_lobby","event":"answer","payload":{"id":"destination_peer","data":"answer_data"},"ref":8}
  {"topic":"lobby:test_lobby","event":"candidate","payload":{"id":"destination_peer","data":"candidate_data"},"ref":9}
  {"topic":"lobby:test_lobby","event":"seal","payload":{},"ref":10}
  ```
  """

  use UroWeb, :channel
  alias Uro.LobbyManager

  @max_lobbies 1024

  def join("lobby:" <> _room_id, _payload, socket) do
    {:ok, assign(socket, :lobbies, %{})}
  end

  def handle_in("join", %{"data" => data}, socket) do
    handle_join(data, socket)
  end

  # Handles incoming "seal" messages. Seals the lobby if the user has permission.
  def handle_in("seal", _params, socket) do
    case Map.fetch(socket.assigns, :lobby) do
      {:ok, lobby_name} ->
        case LobbyManager.seal_lobby(lobby_name, socket.assigns.user_id) do
          :ok ->
            broadcast!(socket, "sealed", %{id: socket.assigns.user_id, type: 7, data: ""})
            {:noreply, socket}

          {:error, reason} ->
            {:reply, {:error, %{reason: reason}}, socket}
        end
      :error ->
        {:reply, {:error, %{reason: "Lobby not found"}}, socket}
    end
  end

  # Handles incoming "offer" messages. Broadcasts the WebRTC offer to the destination peer.
  def handle_in("offer", %{"id" => _id, "data" => data}, socket) do
    broadcast_from!(socket, "offer", %{id: socket.assigns.user_id, type: 4, data: data})
    {:noreply, socket}
  end

  # Handles incoming "answer" messages. Broadcasts the WebRTC answer to the destination peer.
  def handle_in("answer", %{"id" => _id, "data" => data}, socket) do
    broadcast_from!(socket, "answer", %{id: socket.assigns.user_id, type: 5, data: data})
    {:noreply, socket}
  end

  # Handles incoming "candidate" messages. Broadcasts the WebRTC candidate to the destination peer.
  def handle_in("candidate", %{"id" => _id, "data" => data}, socket) do
    broadcast_from!(socket, "candidate", %{id: socket.assigns.user_id, type: 6, data: data})
    {:noreply, socket}
  end

  def handle_in("peer_connect", %{"id" => id, "type" => type, "data" => data}, socket) do
    broadcast!(socket, "peer_connect", %{"id" => id, "type" => type, "data" => data})
    {:noreply, socket}
  end

  def handle_in("peer_disconnect", %{"id" => id, "type" => type, "data" => data}, socket) do
    broadcast!(socket, "peer_disconnect", %{"id" => id, "type" => type, "data" => data})
    {:noreply, socket}
  end

  @doc """
  Handles the `:after_join` message. Sends an ID message to the client.
  """
  def handle_info(:after_join, socket) do
    push(socket, "id", %{id: socket.assigns.user_id, type: 1, data: ""})
    {:noreply, socket}
  end

  defp handle_join(lobby_name, socket) do
    if map_size(socket.assigns.lobbies) < @max_lobbies do
      case LobbyManager.join_lobby(lobby_name, socket.assigns.user_id) do
        {:ok, _lobby} ->
          send(self(), :after_join)
          updated_socket = assign(socket, :lobby, lobby_name)
          {:reply, {:ok, %{id: socket.assigns.user_id, type: 0, data: lobby_name}}, updated_socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: reason}}, socket}
      end
    else
      {:reply, {:error, %{reason: :max_lobbies_reached}}, socket}
    end
  end
end
