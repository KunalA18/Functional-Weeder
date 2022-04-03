defmodule Task2PhoenixServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      Task2PhoenixServerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Task2PhoenixServer.PubSub, adapter: Phoenix.PubSub.PG2},
      # Start the Endpoint (http/https)
      Task2PhoenixServerWeb.Endpoint
      # Start a worker by calling: Task2PhoenixServer.Worker.start_link(arg)
      # {Task2PhoenixServer.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Task2PhoenixServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Task2PhoenixServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
