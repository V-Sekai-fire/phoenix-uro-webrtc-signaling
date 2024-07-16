defmodule Uro.UserSocket do
  use Phoenix.Socket

  channel "lobby:*", Uro.LobbyChannel

  def connect(_params, socket, _connect_info) do
    {:ok, assign(socket, :user_id, random_id())}
  end

  def id(_socket), do: nil

  defp random_id do
    :crypto.strong_rand_bytes(4) |> :binary.decode_unsigned()
  end
end
