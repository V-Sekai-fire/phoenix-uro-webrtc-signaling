defmodule UroWeb.LobbyChannelTest do
  use UroWeb.ChannelCase

  alias Uro.LobbyManager
  alias Uro.UserSocket

  setup do
    case start_supervised({LobbyManager, nil}, restart: :temporary) do
      {:ok, pid} ->
        on_exit(fn -> Process.exit(pid, :normal) end)
      {:error, {:already_started, _pid}} ->
        :ok
    end
    {:ok, socket} = connect(UserSocket, %{"user_id" => "test_user"})
    {:ok, _, socket} = subscribe_and_join(socket, "lobby:test_lobby", %{})
    {:ok, socket: socket}
  end

  describe "JOIN message" do
    test "client joins a lobby and receives confirmation", %{socket: socket} do
      ref = push(socket, "join", %{"data" => "test_lobby"})
      assert_reply ref, :ok, reply
      assert %{id: id, type: 0, data: "test_lobby"} = reply
      assert is_integer(id)
    end
  end

  describe "ID message" do
    test "server sends ID message after client joins", %{socket: socket} do
      ref = push(socket, "join", %{"data" => "test_lobby"})
      assert_reply ref, :ok, _reply
      send(self(), :after_join)
      assert_push "id", %{id: user_id, type: 1, data: ""}
      assert is_integer(user_id)
    end
  end

  describe "PEER_CONNECT message" do
    test "server notifies new peers in the same lobby", %{socket: socket} do
      push(socket, "peer_connect", %{"id" => 123, "type" => 2, "data" => ""})
      assert_broadcast "peer_connect", %{"id" => 123, "type" => 2, "data" => ""}
    end
  end

  describe "PEER_DISCONNECT message" do
    test "server notifies when a peer disconnects", %{socket: socket} do
      broadcast_from!(socket, "peer_disconnect", %{id: 456, type: 3, data: ""})
      assert_receive %Phoenix.Socket.Message{
        event: "peer_disconnect",
        payload: %{id: 456, type: 3, data: ""}
      }
    end
  end

  describe "OFFER message" do
    test "client sends WebRTC offer and server relays it", %{socket: socket} do
      push(socket, "offer", %{id: 789, type: 4, data: "offer_data"})
      assert_broadcast "offer", %{id: user_id, type: 4, data: "offer_data"}
      assert is_integer(user_id)
    end
  end

  describe "ANSWER message" do
    test "client sends WebRTC answer and server relays it", %{socket: socket} do
      _ref = push(socket, "answer", %{"id" => 101112, "data" => "answer_data"})
      assert_broadcast "answer", %{id: user_id, type: 5, data: "answer_data"}
      assert is_integer(user_id)
    end
  end

  describe "CANDIDATE message" do
    test "client sends WebRTC candidate and server relays it", %{socket: socket} do
      _ref = push(socket, "candidate", %{"id" => 131415, "data" => "candidate_data"})
      assert_broadcast "candidate", %{id: user_id, type: 6, data: "candidate_data"}
      assert is_integer(user_id)
    end
  end

  describe "SEAL message" do
    test "SEAL message client seals the lobby and server notifies success", %{socket: socket} do
      _ref = push(socket, "join", %{"data" => "test_lobby"})
      assert_push "id", %{id: id, type: 1, data: ""}
      assert is_integer(id)
      socket = %{socket | assigns: Map.put(socket.assigns, :user_id, id)}
      _ref = push(socket, "seal", %{})
      assert_receive %Phoenix.Socket.Reply{
        status: :ok,
        payload: %{data: "test_lobby", type: 0},
      }
      # TODO: Check for removal of the lobby.
    end
  end
end
