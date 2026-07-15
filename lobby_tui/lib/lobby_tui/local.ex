defmodule LobbyTui.Local do
  @moduledoc """
  The local-terminal transport: the same `LobbyTui.Theatre` the browser runs, in a real TTY. Used for development and as the talk's "same room, second transport" beat until the SSH endpoint lands in pass two.

  Requires a real TTY — `ExRatatui.Server.start_link/1` with `transport: :local` takes over the calling terminal (raw mode, alternate screen) and blocks the caller until the session ends. Run it only from an interactive shell, for example `env -u EX_RATATUI_BUILD iex -S mix` followed by `LobbyTui.Local.run("speaker")`. Never run it detached, backgrounded, or from a non-interactive process — without a real TTY the terminal init fails immediately.
  """

  alias LobbyTui.Lobby

  @doc """
  Joins the lobby as `nickname` and runs the Theatre TUI on the local terminal until the session ends (window closed, process killed, or a fatal render error), then leaves the lobby so the seat and presence entry are freed immediately rather than waiting out the disconnect grace period.

  `avatar_name` picks a seeded avatar by name (the PNG filename minus the extension, e.g. `"crimson"`); when omitted, or when the name does not match any seeded avatar, one is picked at random.
  """
  def run(nickname, avatar_name \\ nil) do
    avatar = pick_avatar(avatar_name)
    attendee = Lobby.join!(nickname, avatar.id)

    {:ok, server} =
      ExRatatui.Server.start_link(
        mod: LobbyTui.Theatre,
        transport: :local,
        attendee: attendee
      )

    ref = Process.monitor(server)

    receive do
      {:DOWN, ^ref, :process, ^server, _reason} ->
        Lobby.leave(attendee)
        :ok
    end
  end

  defp pick_avatar(nil), do: Enum.random(Lobby.list_avatars!())

  defp pick_avatar(name) do
    Enum.find(Lobby.list_avatars!(), &(&1.name == name)) || pick_avatar(nil)
  end
end
