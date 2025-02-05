defmodule Uro.Lobby do
  defstruct peers: [], sealed: false
end

defmodule Uro.State do
  defstruct lobbies: %{}, peers: %{}
end

defmodule Uro.LobbyManager do
  @moduledoc """
  Manages lobbies and peers for a signaling protocol.
  """

  use GenServer

  @max_lobbies 1024
  @max_peers 4096

  @doc """
  Starts the GenServer with an initial state containing empty maps for lobbies and peers.
  """
  def start_link(_) do
    initial_state = %Uro.State{}
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  @doc """
  Initializes the GenServer state.
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Joins a lobby with the given `lobby_name` and `user_id`.
  """
  def join_lobby(lobby_name, user_id) do
    GenServer.call(__MODULE__, {:join_lobby, lobby_name, user_id})
  end

  @doc """
  Seals the lobby with the given `lobby_name` if the `user_id` has permission.
  """
  def seal_lobby(lobby_name, user_id) do
    GenServer.call(__MODULE__, {:seal_lobby, lobby_name, user_id})
  end

  @impl true
  def handle_call({:join_lobby, lobby_name, user_id}, _from, state) do
    if map_size(state.lobbies) < @max_lobbies do
      lobbies = Map.update(state.lobbies, lobby_name, %Uro.Lobby{peers: [user_id]}, fn lobby ->
        if length(lobby.peers) < @max_peers and not lobby.sealed do
          %{lobby | peers: [user_id | lobby.peers]}
        else
          lobby
        end
      end)
      {:reply, {:ok, Map.get(lobbies, lobby_name)}, %{state | lobbies: lobbies}}
    else
      {:reply, {:error, :max_lobbies_reached}, state}
    end
  end

  @impl true
  def handle_call({:seal_lobby, lobby_name, user_id}, _from, state) do
    lobbies = Map.get(state, :lobbies)
    case Map.get(lobbies, lobby_name) do
      nil ->
        {:reply, {:error, :lobby_not_found}, state}
      %{peers: peers} = lobby ->
        if user_id in peers do
          updated_lobby = %{lobby | sealed: true}
          updated_lobbies = Map.put(lobbies, lobby_name, updated_lobby)
          Process.send_after(self(), {:destroy_lobby, lobby_name}, 10_000)
          {:reply, :ok, %{state | lobbies: updated_lobbies}}
        else
          {:reply, {:error, :not_authorized}, state}
        end
      _ ->
        {:reply, {:error, :unknown_error}, state}
    end
  end

  @impl true
  def handle_info({:message, message}, state) do
    case Jason.decode!(message) do
      %{"type" => 0, "data" => data} ->
        handle_join(data, state)
      %{"type" => 1, "id" => id} ->
        handle_id(id, state)
      %{"type" => 2, "id" => id} ->
        handle_peer_connect(id, state)
      %{"type" => 3, "id" => id} ->
        handle_peer_disconnect(id, state)
      %{"type" => 4, "id" => id, "data" => data} ->
        handle_offer(id, data, state)
      %{"type" => 5, "id" => id, "data" => data} ->
        handle_answer(id, data, state)
      %{"type" => 6, "id" => id, "data" => data} ->
        handle_candidate(id, data, state)
      %{"type" => 7} ->
        handle_seal(state)
      _ ->
        :ignore
    end
    {:noreply, state}
  end

  @impl true
  def handle_info({:destroy_lobby, lobby_name}, state) do
    lobbies = Map.delete(state.lobbies, lobby_name)
    {:noreply, %{state | lobbies: lobbies}}
  end

  # Handles the JOIN message. Assigns a new lobby or joins an existing one.
  def handle_join(data, state) do
    lobby_name = if data == "", do: UUID.uuid4(), else: data
    lobbies = Map.update(state.lobbies, lobby_name, %Uro.Lobby{}, &(&1))
    {:noreply, %{state | lobbies: lobbies}}
  end

  # Handles the ID message. Identifies the client when it joins a room.
  def handle_id(id, state) do
    peers = Map.put(state.peers, id, %{})
    {:noreply, %{state | peers: peers}}
  end

  # Handles the PEER_CONNECT message. Notifies new peers in the same lobby.
  def handle_peer_connect(id, state) do
    IO.puts("Peer connected: #{id}")
    {:noreply, state}
  end

  # Handles the PEER_DISCONNECT message. Notifies when a peer in the same lobby disconnects.
  def handle_peer_disconnect(id, state) do
    IO.puts("Peer disconnected: #{id}")
    peers = Map.delete(state.peers, id)
    {:noreply, %{state | peers: peers}}
  end

  # Handles the OFFER message. Relays WebRTC offer to the destination peer.
  def handle_offer(id, data, state) do
    IO.puts("Offer from #{id}: #{data}")
    {:noreply, state}
  end

  # Handles the ANSWER message. Relays WebRTC answer to the destination peer.
  def handle_answer(id, data, state) do
    IO.puts("Answer from #{id}: #{data}")
    {:noreply, state}
  end

  # Handles the CANDIDATE message. Relays WebRTC candidate to the destination peer.
  def handle_candidate(id, data, state) do
    IO.puts("Candidate from #{id}: #{data}")
    {:noreply, state}
  end

  # Handles the SEAL message. Seals the lobby and notifies success.
  def handle_seal(state) do
    IO.puts("Lobby sealed")
    {:noreply, state}
  end
end
