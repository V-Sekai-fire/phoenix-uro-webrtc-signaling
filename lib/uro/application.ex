defmodule Uro.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      UroWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:uro, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Uro.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Uro.Finch},
      # Start a worker by calling: Uro.Worker.start_link(arg)
      # {Uro.Worker, arg},
      # Start to serve requests, typically the last entry
      UroWeb.Endpoint,
      {Uro.LobbyManager, []},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Uro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UroWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
