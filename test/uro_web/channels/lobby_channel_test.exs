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
      assert is_number(id)
    end
  end

  describe "ID message" do
    test "server sends ID message after client joins", %{socket: socket} do
      ref = push(socket, "join", %{"data" => "test_lobby"})
      assert_reply ref, :ok, _reply
      send(self(), :after_join)
      user_id = socket.assigns.user_id
      assert_push "id", %{id: ^user_id, type: 1, data: ""}
    end
  end

  describe "PEER_CONNECT message" do
    test "server notifies new peers in the same lobby", %{socket: socket} do
      push(socket, "peer_connect", %{"id" => "new_peer", "type" => 2, "data" => ""})
      assert_broadcast "peer_connect", %{"id" => "new_peer", "type" => 2, "data" => ""}
    end
  end

  describe "PEER_DISCONNECT message" do
    test "server notifies when a peer disconnects", %{socket: socket} do
      broadcast_from!(socket, "peer_disconnect", %{id: "disconnected_peer", type: 3, data: ""})
      assert_receive %Phoenix.Socket.Message{
        event: "peer_disconnect",
        payload: %{id: "disconnected_peer", type: 3, data: ""}
      }
    end
  end

  # describe "OFFER message" do
  #   test "client sends WebRTC offer and server relays it", %{socket: socket} do
  #     _ref = push(socket, "offer", %{"id" => "destination_peer", "data" => "offer_data"})
  #     assert_broadcast "offer", %{id: "test_user", type: 4, data: "offer_data"}
  #   end
  # end

  # describe "ANSWER message" do
  #   test "client sends WebRTC answer and server relays it", %{socket: socket} do
  #     _ref = push(socket, "answer", %{"id" => "destination_peer", "data" => "answer_data"})
  #     assert_broadcast "answer", %{id: "test_user", type: 5, data: "answer_data"}
  #   end
  # end

  # describe "CANDIDATE message" do
  #   test "client sends WebRTC candidate and server relays it", %{socket: socket} do
  #     _ref = push(socket, "candidate", %{"id" => "destination_peer", "data" => "candidate_data"})
  #     assert_broadcast "candidate", %{id: "test_user", type: 6, data: "candidate_data"}
  #   end
  # end

  # describe "SEAL message" do
  #   test "client seals the lobby and server notifies success", %{socket: socket} do
  #     ref = push(socket, "seal", %{})
  #     assert_reply ref, :ok
  #     assert_broadcast "sealed", %{id: "test_user", type: 7, data: ""}
  #   end
  # end
end
