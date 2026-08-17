defmodule LobbyTui.Lobby.AttendeeTest do
  use ExUnit.Case, async: false

  import LobbyTui.RoomFixtures

  alias LobbyTui.Lobby

  test "join creates an attendee linked to an avatar" do
    avatar = seed_avatar!()
    nick = unique_nickname()
    assert {:ok, attendee} = Lobby.join(nick, avatar.id)
    assert attendee.nickname == nick
    assert attendee.avatar_id == avatar.id
  end

  test "join rejects a duplicate nickname" do
    avatar = seed_avatar!()
    nick = unique_nickname()
    assert {:ok, _} = Lobby.join(nick, avatar.id)
    assert {:error, %Ash.Error.Invalid{}} = Lobby.join(nick, avatar.id)
  end

  test "join rejects nicknames outside 2..16 chars" do
    avatar = seed_avatar!()
    assert {:error, %Ash.Error.Invalid{}} = Lobby.join("x", avatar.id)
    assert {:error, %Ash.Error.Invalid{}} = Lobby.join(String.duplicate("a", 17), avatar.id)
  end

  test "leave removes the attendee" do
    avatar = seed_avatar!()
    {:ok, attendee} = Lobby.join(unique_nickname(), avatar.id)
    assert {:ok, _} = Lobby.leave(attendee)
    assert {:error, _} = Lobby.get_attendee(attendee.id)
  end

  test "the critical concurrency race: N simultaneous same-name joiners all get distinct nicknames" do
    avatar = seed_avatar!()
    base = "race_#{System.unique_integer([:positive])}"

    nicknames =
      1..12
      |> Task.async_stream(fn _ -> LobbyTui.Lobby.Join.join_with_suffix(base, avatar.id) end,
        timeout: :infinity,
        max_concurrency: 12
      )
      |> Enum.map(fn {:ok, {:ok, attendee}} -> attendee.nickname end)

    # Without `Changes.SerializeJoin`, every one of these passes the
    # `unique_nickname` pre-check before any of them writes, so all twelve
    # join un-suffixed and this collapses to one distinct name.
    assert length(Enum.uniq(nicknames)) == 12
    assert base in nicknames
  end

  test "join_with_suffix refuses instead of crashing once every suffix is taken" do
    avatar = seed_avatar!()
    base = "full_#{System.unique_integer([:positive])}"

    for _ <- 1..50, do: {:ok, _} = LobbyTui.Lobby.Join.join_with_suffix(base, avatar.id)

    assert LobbyTui.Lobby.Join.join_with_suffix(base, avatar.id) ==
             {:error, :nickname_unavailable}
  end

  test "list_avatars! returns seeded avatars" do
    avatar = seed_avatar!()
    assert Enum.any?(Lobby.list_avatars!(), &(&1.id == avatar.id))
  end
end
