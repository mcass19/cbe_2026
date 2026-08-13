defmodule LobbyTui.Local do
  @moduledoc """
  The local-terminal transport: the same `LobbyTui.Theatre` the browser runs, in a real TTY. Used for development and as the talk's "same room, second transport" beat until the SSH endpoint lands in pass two.

  Requires a real TTY — `ExRatatui.Server.start_link/1` with `transport: :local` takes over the calling terminal (raw mode, alternate screen) and blocks the caller until the session ends. Run it only from an interactive shell, for example `iex -S mix` followed by `LobbyTui.Local.run("speaker")`. Never run it detached, backgrounded, or from a non-interactive process — without a real TTY the terminal init fails immediately.
  """

  alias LobbyTui.Lobby
  alias LobbyTui.Lobby.Join

  @doc """
  Joins the lobby as `nickname` and runs the Theatre TUI on the local terminal until the session ends (`q`, window closed, process killed, or a fatal render error), then leaves the lobby so the seat and presence entry are freed immediately rather than waiting out the disconnect grace period.

  `avatar_name` picks a seeded avatar by name (the PNG filename minus the extension, e.g. `"monk"`); when omitted, or when the name does not match any seeded avatar, one is picked at random.

  Passes `quit?: true` to `Theatre.mount/1` — press `q` to leave. This is a local-terminal-only affordance: the browser embed never sets it, so a stray "q" typed into the room from a browser tab cannot kill that attendee's TUI process.

  Returns `:ok` when the session ends normally and `{:error, reason}` when the server exits abnormally or the terminal cannot be initialised (for example, no TTY). Exits are trapped for the duration of the call (the flag is restored afterwards), so a server crash lands here instead of killing the caller — and in every case the attendee row is removed before returning, keeping the nickname free for the next attempt.
  """
  def run(nickname, avatar_name \\ nil) do
    avatar = Join.pick_avatar(avatar_name)
    attendee = Lobby.join!(nickname, avatar.id)
    trapping? = Process.flag(:trap_exit, true)

    try do
      case ExRatatui.Server.start_link(
             mod: LobbyTui.Theatre,
             transport: :local,
             attendee: attendee,
             quit?: true
           ) do
        {:ok, server} ->
          receive do
            {:EXIT, ^server, reason} when reason in [:normal, :shutdown] -> :ok
            {:EXIT, ^server, reason} -> {:error, reason}
          end

        {:error, reason} ->
          flush_exit()
          {:error, reason}
      end
    after
      Process.flag(:trap_exit, trapping?)
      Lobby.leave(attendee)
    end
  end

  # A failed start_link may still deliver the dead server's {:EXIT, _, _}
  # message (exits are being trapped); drop it so the caller's mailbox — the
  # iex shell, typically — is left as found.
  defp flush_exit do
    receive do
      {:EXIT, _pid, _reason} -> :ok
    after
      0 -> :ok
    end
  end
end
