defmodule LobbyTui.Ssh do
  @moduledoc """
  The SSH transport: the same `LobbyTui.Theatre` the browser and the local terminal run, served to anyone who types `ssh <nickname>@lobby-tui.fly.dev`.

  This is the third transport shim, symmetric with `LobbyTuiWeb.TheatreComponent` (browser), `LobbyTui.Local` (local terminal), and `LobbyTui.Notebook` (Livebook): it turns a connection into an attendee, then delegates every ExRatatui callback to `Theatre`. `ExRatatui.SSH.Daemon` gives each client its own isolated session, server, and state, so no per-connection supervision is needed here.

  The nickname is the username the client offered — `ssh alice@…` joins as "alice". It is sanitized (unprintables dropped, trimmed, clamped to the 16-character attendee limit) and, when already taken, suffixed until it is free: "alice", "alice-2", "alice-3". A client that offers nothing usable joins as "guest". The daemon runs without authentication, so the username is a display name and nothing more — never an identity, and never a basis for authorization.
  """

  use ExRatatui.App

  alias LobbyTui.{Lobby, Theatre}
  alias LobbyTui.Lobby.Join

  @default_port 2222

  # A public endpoint with no authentication needs its own ceilings:
  # enough room for a conference audience, and a cap on connections
  # someone opened and walked away from.
  @default_max_sessions 150
  @default_idle_time :timer.minutes(30)

  @doc """
  The `ExRatatui.SSH.Daemon` child spec for the supervision tree, or `nil` when the endpoint is switched off.

  Reads `config :lobby_tui, :ssh` — `:enabled`, `:port`, `:host_key_base64`, `:host_key_dir`. With a base64 host key configured (in production, from the `SSH_HOST_KEY` secret) the key is written to disk and passed as `:system_dir`, so it survives redeploys and returning clients never see a changed-host-key warning; without one the daemon generates its own under `priv/`. Passing both is an error, so exactly one is ever set.
  """
  def daemon_spec do
    config = Application.get_env(:lobby_tui, :ssh, [])

    if Keyword.get(config, :enabled, false) do
      opts =
        [
          mod: __MODULE__,
          port: Keyword.get(config, :port, @default_port),
          no_auth_needed: true,
          max_sessions: Keyword.get(config, :max_sessions, @default_max_sessions),
          idle_time: Keyword.get(config, :idle_time, @default_idle_time)
        ]
        |> put_host_key(config)

      {ExRatatui.SSH.Daemon, opts}
    end
  end

  @doc """
  Writes a base64-encoded private host key into `dir` under the filename OTP scans for, with owner-only permissions, and returns `dir` as the charlist `:system_dir` expects.
  """
  def materialize_host_key!(dir, base64) do
    path = Path.join(dir, "ssh_host_ed25519_key")

    File.mkdir_p!(dir)
    File.write!(path, Base.decode64!(base64))
    File.chmod!(path, 0o600)

    String.to_charlist(dir)
  end

  defp put_host_key(opts, config) do
    case Keyword.get(config, :host_key_base64) do
      nil ->
        Keyword.put(opts, :auto_host_key, true)

      base64 ->
        dir = Keyword.get(config, :host_key_dir, default_host_key_dir())
        Keyword.put(opts, :system_dir, materialize_host_key!(dir, base64))
    end
  end

  defp default_host_key_dir, do: Path.join(System.tmp_dir!(), "lobby_tui_ssh")

  @impl true
  def mount(opts) do
    attendee =
      opts
      |> Keyword.get(:ssh_user)
      |> Join.sanitize_nickname()
      |> Join.join_with_suffix(Join.pick_avatar(nil).id)

    opts
    |> Keyword.take([:connect?])
    |> Keyword.merge(attendee: attendee, quit?: true)
    |> Theatre.mount()
  end

  @impl true
  def render(state, frame), do: Theatre.render(state, frame)

  @impl true
  def handle_event(event, state), do: Theatre.handle_event(event, state)

  @impl true
  def handle_info(msg, state), do: Theatre.handle_info(msg, state)

  @doc """
  Leaves the room as the connection drops.

  An SSH disconnect is unambiguous — there is no tab to refresh and no phone to unlock — so the attendee and their seat are released immediately instead of waiting out `LobbyTui.Reaper`'s presence grace period.
  """
  @impl true
  def terminate(_reason, %Theatre.State{attendee: attendee}) when not is_nil(attendee) do
    Lobby.leave(attendee)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  @doc """
  Reduces an SSH username to something the `Attendee` resource will accept — see `LobbyTui.Lobby.Join.sanitize_nickname/1`, which every free-form-name transport shares.
  """
  defdelegate sanitize_nickname(user), to: Join
end
