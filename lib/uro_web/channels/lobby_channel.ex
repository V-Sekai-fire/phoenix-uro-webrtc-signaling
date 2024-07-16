defmodule UroWeb.LobbyChannel do
  @moduledoc """
  Handles WebSocket connections for lobby management and peer communication.

  ## Signaling Protocol

  The protocol is JSON based, and uses messages in the form:

  {
    "id": "number",
    "type": "number",
    "data": "string"
  }

  With `type` being the message type, `id` being a connected peer or `0`, and `data` being the message specific data.

  Messages are the following:

  - `0 = JOIN`: Must be sent by client immediately after connection to get a lobby assigned or join a known one (via the `data` field). This message is also sent by server back to the client to notify the assigned lobby, or simply a successful join.
  - `1 = ID`: Sent by server to identify the client when it joins a room (the `id` field will contain the assigned ID).
  - `2 = PEER_CONNECT`: Sent by server to notify new peers in the same lobby (the `id` field will contain the ID of the new peer).
  - `3 = PEER_DISCONNECT`: Sent by server to notify when a peer in the same lobby disconnects (the `id` field will contain the ID of the disconnected peer).
  - `4 = OFFER`: Sent by the client when creating a WebRTC offer then relayed back by the server to the destination peer.
  - `5 = ANSWER`: Sent by the client when creating a WebRTC answer then relayed back by the server to the destination peer.
  - `6 = CANDIDATE`: Sent by the client when generating new WebRTC candidates then relayed back by the server to the destination peer.
  - `7 = SEAL`: Sent by client to seal the lobby (only the client that created it is allowed to seal a lobby), and then back by the server to notify success. When a lobby is sealed, no new client will be able to join, and the lobby will be destroyed (and clients disconnected) after 10 seconds.

  For relayed messages (i.e., for `OFFER`, `ANSWER`, and `CANDIDATE`), the client will set the `id` field as the destination peer, then the server will replace it with the id of the sending peer, and send it to the proper destination.
  """

  use UroWeb, :channel
  alias Uro.LobbyManager

  @max_peers 4096
  @max_lobbies 1024
  @ping_interval 10_000

  # Joins a lobby with the given `lobby_name`. Assigns the user to the lobby and sends a join confirmation.
  def join("lobby:" <> lobby_name, _params, socket) do
    handle_join(lobby_name, socket)
  end

  # Handles incoming "join" messages. Attempts to join the specified lobby.
  def handle_in("join", %{"data" => data}, socket) do
    handle_join(data, socket)
  end

  # Handles incoming "seal" messages. Seals the lobby if the user has permission.
  def handle_in("seal", _params, socket) do
    case LobbyManager.seal_lobby(socket.assigns.lobby, socket.assigns.user_id) do
      :ok ->
        broadcast!(socket, "sealed", %{id: socket.assigns.user_id, type: 7, data: ""})
        {:noreply, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  # Handles incoming "offer" messages. Broadcasts the WebRTC offer to the destination peer.
  def handle_in("offer", %{"id" => id, "data" => data}, socket) do
    broadcast_from!(socket, "offer", %{id: socket.assigns.user_id, type: 4, data: data})
    {:noreply, socket}
  end

  # Handles incoming "answer" messages. Broadcasts the WebRTC answer to the destination peer.
  def handle_in("answer", %{"id" => id, "data" => data}, socket) do
    broadcast_from!(socket, "answer", %{id: socket.assigns.user_id, type: 5, data: data})
    {:noreply, socket}
  end

  # Handles incoming "candidate" messages. Broadcasts the WebRTC candidate to the destination peer.
  def handle_in("candidate", %{"id" => id, "data" => data}, socket) do
    broadcast_from!(socket, "candidate", %{id: socket.assigns.user_id, type: 6, data: data})
    {:noreply, socket}
  end

  @doc """
  Handles the `:after_join` message. Sends an ID message to the client.
  """
  def handle_info(:after_join, socket) do
    push(socket, "id", %{id: socket.assigns.user_id, type: 1, data: ""})
    {:noreply, socket}
  end

  # Private function to handle joining a lobby
  defp handle_join(lobby_name, socket) do
    case LobbyManager.join_lobby(lobby_name, socket.assigns.user_id) do
      {:ok, lobby} ->
        send(self(), :after_join)
        push(socket, "joined", %{id: socket.assigns.user_id, type: 0, data: lobby})
        {:ok, %{lobby: lobby}, assign(socket, :lobby, lobby)}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
end
