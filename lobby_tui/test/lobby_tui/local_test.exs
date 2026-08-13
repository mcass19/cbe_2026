defmodule LobbyTui.LocalTest do
  use ExUnit.Case, async: false

  alias LobbyTui.Lobby

  # A failed terminal start is the path that used to kill the calling process
  # through the server link and leak the attendee row ("nickname has already
  # been taken" on the next attempt). The failure is injected via the
  # `:start_server` seam rather than relying on the environment: with a real
  # TTY (a developer's terminal) `ExRatatui.Server.start_link/1` would
  # SUCCEED, take over the screen with a live TUI, and block until `q`.

  defp failed_start(_server_opts), do: {:error, {:terminal_init_failed, :forced}}

  defp run_with_failed_start(nickname) do
    LobbyTui.Local.run(nickname, nil, start_server: &failed_start/1)
  end

  test "a failed terminal start returns an error instead of killing the caller" do
    assert {:error, {:terminal_init_failed, :forced}} =
             run_with_failed_start("local_#{System.unique_integer([:positive])}")
  end

  test "a failed terminal start frees the nickname for the next attempt" do
    nickname = "local_#{System.unique_integer([:positive])}"

    {:error, _reason} = run_with_failed_start(nickname)

    avatar = Enum.random(Lobby.list_avatars!())
    attendee = Lobby.join!(nickname, avatar.id)
    Lobby.leave(attendee)
  end

  test "run restores the caller's trap_exit flag" do
    {:trap_exit, false} = Process.info(self(), :trap_exit)

    {:error, _reason} = run_with_failed_start("local_#{System.unique_integer([:positive])}")

    assert {:trap_exit, false} = Process.info(self(), :trap_exit)
  end
end
