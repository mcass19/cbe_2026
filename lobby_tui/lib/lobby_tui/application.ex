defmodule LobbyTui.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LobbyTuiWeb.Telemetry,
      {Phoenix.PubSub, name: LobbyTui.PubSub},
      LobbyTui.Presence,
      LobbyTui.Reaper,
      LobbyTui.Keeper,
      LobbyTui.RateLimiter,
      LobbyTui.SpriteLoader,
      LobbyTui.Scene,
      # Start a worker by calling: LobbyTui.Worker.start_link(arg)
      # {LobbyTui.Worker, arg},
      # Start to serve requests, typically the last entry
      LobbyTuiWeb.Endpoint
    ]

    # The SSH entry point is opt-in per environment: on in production,
    # `LOBBY_SSH=1` in development, off under test.
    children = children ++ Enum.reject([LobbyTui.Ssh.daemon_spec()], &is_nil/1)

    LobbyTui.Lobby.Seeder.seed_seats!()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LobbyTui.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LobbyTuiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
