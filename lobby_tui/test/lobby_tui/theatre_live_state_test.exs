defmodule LobbyTui.TheatreLiveStateTest do
  use ExUnit.Case, async: false

  alias LobbyTui.{Lobby, Theatre}

  setup do
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  defp mount_connected! do
    avatar =
      Lobby.seed_avatar!(%{
        name: "l_#{System.unique_integer([:positive])}",
        sprite_cells: [],
        dominant_color: {:rgb, 1, 1, 1},
        license: "CC0",
        attribution: "test"
      })

    attendee = Lobby.join!("live_#{System.unique_integer([:positive])}", avatar.id)
    {:ok, state} = Theatre.mount(attendee: attendee, connect?: true)
    state
  end

  test "connecting tracks presence and loads current occupancy" do
    state = mount_connected!()
    presences = LobbyTui.Presence.list(LobbyTui.Presence.topic())
    assert Map.has_key?(presences, state.attendee.id)
  end

  test "a seat broadcast updates occupied; a release clears it" do
    state = mount_connected!()
    other = Lobby.join!("occ_#{System.unique_integer([:positive])}", state.attendee.avatar_id)
    seat = Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id))
    {:ok, claimed} = Lobby.claim_seat(seat, actor: other)

    assert_receive %Phoenix.Socket.Broadcast{topic: "lobby:seats"} = broadcast
    {:noreply, state} = Theatre.handle_info(broadcast, state)
    assert state.occupied[{seat.x, seat.y}] == other.id

    _ = Lobby.release_seat!(claimed)
    assert_receive %Phoenix.Socket.Broadcast{topic: "lobby:seats"} = release_broadcast
    {:noreply, state} = Theatre.handle_info(release_broadcast, state)
    refute Map.has_key?(state.occupied, {seat.x, seat.y})
  end

  test "remounting while still holding a seat (refresh/reconnect) comes up seated with a loaded feed" do
    state = mount_connected!()
    seat = Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id))
    {:ok, _} = Lobby.claim_seat(seat, actor: state.attendee)
    assert_receive %Phoenix.Socket.Broadcast{topic: "lobby:seats"}

    {:ok, _message} = Lobby.post_message("still here after refresh", actor: state.attendee)
    assert_receive %Phoenix.Socket.Broadcast{topic: "lobby:stage"}

    # A real refresh/reconnect spawns a brand-new process (new LiveView, new
    # ExRatatui.Server) — mount from a separate process here too, since
    # Presence.track/4 keys on the calling pid and a second track from the
    # same pid for the same attendee id would collide with the first.
    remounted =
      Task.async(fn -> Theatre.mount(attendee: state.attendee, connect?: true) end)
      |> Task.await()

    assert {:ok, remounted} = remounted
    assert remounted.seated?
    assert Enum.any?(remounted.feed, &(&1.body == "still here after refresh"))
  end

  test "a stage broadcast prepends to a seated attendee's feed and is ignored unseated" do
    state = mount_connected!()
    poster = Lobby.join!("post_#{System.unique_integer([:positive])}", state.attendee.avatar_id)
    seat = Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id))
    {:ok, _} = Lobby.claim_seat(seat, actor: poster)
    {:ok, msg} = Lobby.post_message("broadcast me", actor: poster)

    assert_receive %Phoenix.Socket.Broadcast{topic: "lobby:stage"} = broadcast

    {:noreply, unseated_after} = Theatre.handle_info(broadcast, state)
    assert unseated_after.feed == []

    seated = %{state | seated?: true}
    {:noreply, seated_after} = Theatre.handle_info(broadcast, seated)
    assert [%{id: id} | _] = seated_after.feed
    assert id == msg.id
  end
end
