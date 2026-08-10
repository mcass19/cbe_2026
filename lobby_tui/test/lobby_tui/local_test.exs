defmodule LobbyTui.LocalTest do
  use ExUnit.Case, async: false

  alias LobbyTui.Lobby

  # The test run has no TTY, so the local transport always fails at terminal
  # init — the exact path that used to kill the calling process through the
  # server link and leak the attendee row ("nickname has already been taken"
  # on the next attempt).

  test "a failed terminal start returns an error instead of killing the caller" do
    assert {:error, _reason} = LobbyTui.Local.run("local_#{System.unique_integer([:positive])}")
  end

  test "a failed terminal start frees the nickname for the next attempt" do
    nickname = "local_#{System.unique_integer([:positive])}"

    {:error, _reason} = LobbyTui.Local.run(nickname)

    avatar = Enum.random(Lobby.list_avatars!())
    attendee = Lobby.join!(nickname, avatar.id)
    Lobby.leave(attendee)
  end

  test "run restores the caller's trap_exit flag" do
    {:trap_exit, false} = Process.info(self(), :trap_exit)

    {:error, _reason} = LobbyTui.Local.run("local_#{System.unique_integer([:positive])}")

    assert {:trap_exit, false} = Process.info(self(), :trap_exit)
  end
end
