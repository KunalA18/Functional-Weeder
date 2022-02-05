defmodule Task4CPhoenixServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      Task4CPhoenixServerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Task4CPhoenixServer.PubSub, adapter: Phoenix.PubSub.PG2},
      # Start the Endpoint (http/https)
      Task4CPhoenixServerWeb.Endpoint,
      # Start a worker by calling: Task4CPhoenixServer.Worker.start_link(arg)
      # {Task4CPhoenixServer.Worker, arg}
      {Task4CPhoenixServer.Timer, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Task4CPhoenixServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Task4CPhoenixServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
