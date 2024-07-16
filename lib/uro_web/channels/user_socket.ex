defmodule Uro.UserSocket do
  use Phoenix.Socket

  channel "lobby:*", UroWeb.LobbyChannel

  def connect(_params, socket, _connect_info) do
    user_id = random_id()
    lobbies = %{}

    {:ok, assign(socket, :user_id, user_id) |> assign(:lobbies, lobbies)}
  end

  def id(_socket), do: nil

  defp random_id do
    :crypto.strong_rand_bytes(4) |> :binary.decode_unsigned()
  end
end
