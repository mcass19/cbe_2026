defmodule LobbyTui.TheatreLiveStateTest do
  use ExUnit.Case, async: false

  import LobbyTui.RoomFixtures

  alias LobbyTui.{Lobby, Theatre}

  setup do
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  defp mount_connected! do
    attendee = join!(prefix: "live")
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
    # `other` never mounted a Theatre (never tracked in Presence), so the
    # color lookup misses and the entry stores the fallback.
    assert state.occupied[{seat.x, seat.y}] == %{id: other.id, color: :red}

    _ = Lobby.stand!(claimed, actor: other)
    assert_receive %Phoenix.Socket.Broadcast{topic: "lobby:seats"} = release_broadcast
    {:noreply, state} = Theatre.handle_info(release_broadcast, state)
    refute Map.has_key?(state.occupied, {seat.x, seat.y})
  end

  test "a seat broadcast for a tracked occupant stores their real presence color" do
    state = mount_connected!()
    tracked = mount_connected!()
    seat = Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id))
    {:ok, _claimed} = Lobby.claim_seat(seat, actor: tracked.attendee)

    assert_receive %Phoenix.Socket.Broadcast{topic: "lobby:seats"} = broadcast
    {:noreply, state} = Theatre.handle_info(broadcast, state)
    assert state.occupied[{seat.x, seat.y}] == %{id: tracked.attendee.id, color: tracked.color}
  end

  test "connect's initial occupancy load stores the occupant's presence color" do
    holder = mount_connected!()
    seat = Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id))
    {:ok, _} = Lobby.claim_seat(seat, actor: holder.attendee)

    late_joiner = mount_connected!()

    assert late_joiner.occupied[{seat.x, seat.y}] == %{
             id: holder.attendee.id,
             color: holder.color
           }
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
    # The curtain tick and the Presence entry belong to that process, so
    # they are read from inside it.
    {remounted, curtain_tick, presence} =
      Task.async(fn ->
        {:ok, remounted} = Theatre.mount(attendee: state.attendee, connect?: true)
        tick = receive do: (:curtain_tick -> :curtain_tick), after: (500 -> :none)
        presence = LobbyTui.Presence.get_by_key(LobbyTui.Presence.topic(), state.attendee.id)
        {remounted, tick, presence}
      end)
      |> Task.await()

    assert remounted.seated?
    assert Enum.any?(remounted.feed, &(&1.body == "still here after refresh"))

    # The curtain rises again, as it does for a fresh sit, rather than
    # staying shut over the feed until the attendee stands and re-sits.
    assert curtain_tick == :curtain_tick

    # Back on the seat's anchor, for us and for everyone else. The first
    # mount is still alive in this test process (a real reload would have
    # killed it), so the attendee has two Presence entries here.
    anchor = LobbyTui.World.seat_anchor(seat.row, seat.col)
    assert remounted.pos == anchor
    assert Enum.any?(presence.metas, &({&1.x, &1.y} == anchor))
  end

  test "remounting unseated lands on the walkway, curtain shut" do
    state = mount_connected!()

    {remounted, curtain_tick} =
      Task.async(fn ->
        {:ok, remounted} = Theatre.mount(attendee: state.attendee, connect?: true)
        {remounted, receive(do: (:curtain_tick -> :curtain_tick), after: (100 -> :none))}
      end)
      |> Task.await()

    refute remounted.seated?
    assert curtain_tick == :none
    assert LobbyTui.World.tile_at(remounted.pos) == :floor
    assert LobbyTui.World.seat_at(remounted.pos) == nil
  end

  test "a stage broadcast prepends to a seated attendee's feed and is ignored unseated" do
    state = mount_connected!()
    poster = Lobby.join!("post_#{System.unique_integer([:positive])}", state.attendee.avatar_id)
    seat = Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id))
    {:ok, _} = Lobby.claim_seat(seat, actor: poster)
    {:ok, msg} = Lobby.post_message("broadcast me", actor: poster)

    assert_receive %Phoenix.Socket.Broadcast{topic: "lobby:stage"} = broadcast

    {:noreply, unseated_after, render?: false} = Theatre.handle_info(broadcast, state)
    assert unseated_after.feed == []

    seated = %{state | seated?: true}
    {:noreply, seated_after} = Theatre.handle_info(broadcast, seated)
    assert [%{id: id} | _] = seated_after.feed
    assert id == msg.id

    # The same message again (a reconnect replay) changes nothing on stage.
    assert {:noreply, ^seated_after, render?: false} =
             Theatre.handle_info(broadcast, seated_after)
  end

  # The runtime redraws after every message unless told otherwise, so diffs
  # that only arm (or ride) the refresh timer must skip the redraw; the
  # timer's `:refresh_others` is the one that draws the moved attendees.
  test "presence diffs skip the redraw until the coalesced refresh" do
    state = mount_connected!()
    diff = %Phoenix.Socket.Broadcast{event: "presence_diff", topic: "lobby:presence"}

    assert {:noreply, armed, render?: false} = Theatre.handle_info(diff, state)
    assert armed.refresh_pending?
    assert {:noreply, ^armed, render?: false} = Theatre.handle_info(diff, armed)

    assert_receive :refresh_others, 500
    assert {:noreply, refreshed} = Theatre.handle_info(:refresh_others, armed)
    refute refreshed.refresh_pending?
  end

  test "unrelated messages skip the redraw" do
    state = mount_connected!()
    assert {:noreply, ^state, render?: false} = Theatre.handle_info(:unrelated, state)
  end
end
