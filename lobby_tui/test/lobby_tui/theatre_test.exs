defmodule LobbyTui.TheatreTest do
  use ExUnit.Case, async: false

  alias ExRatatui.Event.Key
  alias LobbyTui.{Lobby, Theatre}

  setup do
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  defp mount!(extra \\ []) do
    avatar =
      Lobby.seed_avatar!(%{
        name: "t_#{System.unique_integer([:positive])}",
        sprite_cells: [],
        dominant_color: {:rgb, 9, 9, 9},
        license: "CC0",
        attribution: "test"
      })

    attendee = Lobby.join!("thea_#{System.unique_integer([:positive])}", avatar.id)
    {:ok, state} = Theatre.mount([attendee: attendee, connect?: false] ++ extra)
    state
  end

  defp press(state, code) do
    {:noreply, state} = Theatre.handle_event(%Key{code: code, kind: "press"}, state)
    state
  end

  test "mounts at the spawn point, unseated, with the avatar's color" do
    state = mount!()
    assert state.pos == LobbyTui.World.spawn_point()
    refute state.seated?
    assert state.color == {:rgb, 9, 9, 9}
  end

  # 2 fully transparent top rows (every cell {" ", nil, nil}) over an opaque
  # bottom row — the avatar cache must carry the leading-transparent-row
  # count so the render compositor can hug the label to the sprite's
  # visible pixels instead of floating it a fixed 6 rows above the anchor.
  @top_trim_sprite [
    [{" ", nil, nil}, {" ", nil, nil}],
    [{" ", nil, nil}, {" ", nil, nil}],
    [{"█", :cyan, nil}, {"█", :cyan, nil}]
  ]

  test "avatar cache entries carry the leading-transparent-row trim" do
    avatar =
      Lobby.seed_avatar!(%{
        name: "trimmed_#{System.unique_integer([:positive])}",
        sprite_cells: @top_trim_sprite,
        dominant_color: {:rgb, 1, 2, 3},
        license: "CC0",
        attribution: "test"
      })

    attendee = Lobby.join!("trim_#{System.unique_integer([:positive])}", avatar.id)
    {:ok, state} = Theatre.mount(attendee: attendee, connect?: false)

    assert %{top_trim: 2} = state.avatar_cache[avatar.id]
  end

  test "an avatar with empty sprite cells caches a zero trim" do
    state = mount!()
    avatar_id = state.attendee.avatar_id

    assert %{top_trim: 0} = state.avatar_cache[avatar_id]
  end

  test "arrow keys move; walls block" do
    state = mount!()
    {x, y} = state.pos
    assert press(state, "up").pos == {x, y - 1}
    assert press(state, "left").pos == {x - 1, y}

    at_wall = %{state | pos: {1, 27}}
    assert press(at_wall, "left").pos == {1, 27}
  end

  test "another attendee's cell blocks movement" do
    state = mount!()
    {x, y} = state.pos

    blocked = %{
      state
      | others_by_pos: %{{x, y - 1} => %{nickname: "o", color: nil, x: x, y: y - 1}}
    }

    assert press(blocked, "up").pos == {x, y}
  end

  defp fresh_free_seat! do
    seat = Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id)) || flunk("no free seat")
    %{x: seat.x, y: seat.y}
  end

  test "sit on a free seat cell claims it and loads the feed" do
    state = mount!()
    seat = fresh_free_seat!()
    seated = press(%{state | pos: {seat.x, seat.y}}, "s")
    assert seated.seated?
    assert {:ok, _} = Lobby.seat_of(state.attendee.id)
  end

  test "sit away from a seat sets a hint instead" do
    state = mount!()
    hinted = press(state, "s")
    refute hinted.seated?
    assert hinted.hint =~ "seat"
  end

  # The bug this covers: the seat used to be its anchor cell alone, so
  # standing anywhere else on the painted block silently refused to sit.
  test "sit works from any cell of the seat's painted block, snapping to the anchor" do
    seat = fresh_free_seat!()
    {dx_range, dy_range} = LobbyTui.World.footprint_offsets()

    for {dx, dy} <- [
          {dx_range.first, dy_range.first},
          {dx_range.last, dy_range.last},
          {0, dy_range.first},
          {dx_range.first, 0}
        ] do
      state = mount!()
      corner = {seat.x + dx, seat.y + dy}
      seated = press(%{state | pos: corner}, "s")

      assert seated.seated?, "expected to sit from #{inspect(corner)}"
      assert seated.pos == {seat.x, seat.y}, "expected to snap onto the anchor"

      press(seated, " ")
    end
  end

  # The regression: seats are seeded into ETS at boot, and the seat record
  # was previously looked up by its stored coordinates. Move the world's
  # geometry and every seat in the house silently stops accepting `s`,
  # with no error anywhere — the whole room just becomes furniture. Row and
  # column are the seat's identity and never move, so the lookup uses those.
  test "every seat in the house is sittable, whatever the seeded coordinates say" do
    seeded = Lobby.list_seats!()
    assert length(seeded) == length(LobbyTui.World.seats())

    # Sampled from whatever is free rather than from fixed coordinates —
    # other tests in this file claim seats too — but spread across distinct
    # rows so a whole band of the house going dead would still show up.
    sample =
      seeded
      |> Enum.filter(&is_nil(&1.occupant_id))
      |> Enum.group_by(& &1.row)
      |> Enum.sort_by(fn {row, _} -> row end)
      |> Enum.map(fn {_row, seats} -> hd(seats) end)
      |> Enum.take(5)

    assert length(sample) >= 3, "not enough free seats left to sample the house"

    for record <- sample do
      world_seat =
        Enum.find(LobbyTui.World.seats(), &(&1.row == record.row and &1.col == record.col))

      assert world_seat, "seeded seat #{record.row}/#{record.col} is not in the world"

      state = mount!()
      seated = press(%{state | pos: {world_seat.x, world_seat.y}}, "s")

      assert seated.seated?,
             "row #{record.row} col #{record.col} at #{inspect({world_seat.x, world_seat.y})} refused to seat"

      press(seated, " ")
    end
  end

  test "a seated attendee cannot walk out of their seat" do
    state = mount!()
    seat = fresh_free_seat!()
    seated = press(%{state | pos: {seat.x, seat.y}}, "s")
    assert seated.seated?

    for dir <- ~w(up down left right) do
      moved = press(seated, dir)
      assert moved.pos == {seat.x, seat.y}, "#{dir} moved a seated attendee"
      assert {:ok, _} = Lobby.seat_of(state.attendee.id)
    end

    # Left/right hint toward standing; up/down leaf the stage feed instead
    # (see the "seated feed scrolling" describe).
    for dir <- ~w(left right) do
      assert press(seated, dir).hint =~ "stand"
    end
  end

  test "sit on a taken seat sets a hint" do
    other = mount!()
    seat = fresh_free_seat!()
    _other_seated = press(%{other | pos: {seat.x, seat.y}}, "s")

    state = mount!()
    hinted = press(%{state | pos: {seat.x, seat.y}}, "s")
    refute hinted.seated?
    assert hinted.hint =~ "taken"
  end

  test "{:say, body} posts when seated and hints when rate-limited" do
    state = mount!()
    seat = fresh_free_seat!()
    seated = press(%{state | pos: {seat.x, seat.y}}, "s")

    {:noreply, after_say} = Theatre.handle_info({:say, "hello"}, seated)
    assert Enum.any?(after_say.feed, &(&1.body == "hello"))

    limited =
      Enum.reduce(1..7, seated, fn i, acc ->
        {:noreply, acc} = Theatre.handle_info({:say, "m#{i}"}, acc)
        acc
      end)

    assert limited.hint =~ "slow down"
  end

  test "seated + left/right does not move, hints to stand" do
    state = mount!()
    seat = fresh_free_seat!()
    seated = press(%{state | pos: {seat.x, seat.y}}, "s")
    assert seated.seated?

    moved = press(seated, "left")
    assert moved.pos == seated.pos
    assert moved.hint =~ "press space to stand"
  end

  describe "seated feed scrolling" do
    alias LobbyTui.Theatre.{Render, State}

    # Scrolling is a pure state transition, so these build State directly
    # instead of walking the join/sit flow.
    defp seated_with_feed(count) do
      attendee = %LobbyTui.Lobby.Attendee{id: "self", nickname: "me", avatar_id: nil}
      feed = for i <- count..1//-1, do: %{id: i, author_nickname: "n", body: "m#{i}"}
      %{State.new(attendee, :cyan) | seated?: true, feed: feed}
    end

    test "up leafs toward older messages, clamped at the feed's end" do
      # Two more messages than the stage shows: max scroll is exactly 2.
      state = seated_with_feed(Render.stage_line_count() + 2)

      once = press(state, "up")
      assert once.feed_scroll == 1

      settled = Enum.reduce(1..10, state, fn _press, acc -> press(acc, "up") end)
      assert settled.feed_scroll == 2
    end

    test "up does nothing when the whole feed already fits on stage" do
      state = seated_with_feed(2)
      assert press(state, "up").feed_scroll == 0
    end

    test "down leafs back toward the newest, clamped at zero" do
      state = %{seated_with_feed(Render.stage_line_count() + 2) | feed_scroll: 1}

      back = press(state, "down")
      assert back.feed_scroll == 0
      assert press(back, "down").feed_scroll == 0
    end

    test "a scrolled reader keeps their place when a new message lands" do
      state = %{seated_with_feed(12) | feed_scroll: 3}

      broadcast = %Phoenix.Socket.Broadcast{
        topic: "lobby:stage",
        event: "create",
        payload: %Ash.Notifier.Notification{data: %{id: 99, author_nickname: "x", body: "new"}}
      }

      {:noreply, landed} = Theatre.handle_info(broadcast, state)
      assert length(landed.feed) == 13
      assert landed.feed_scroll == 4
    end

    test "pinned to newest stays pinned when a new message lands" do
      state = seated_with_feed(12)

      broadcast = %Phoenix.Socket.Broadcast{
        topic: "lobby:stage",
        event: "create",
        payload: %Ash.Notifier.Notification{data: %{id: 99, author_nickname: "x", body: "new"}}
      }

      {:noreply, landed} = Theatre.handle_info(broadcast, state)
      assert landed.feed_scroll == 0
    end
  end

  test "seated + space frees the seat, clears seated? and the feed" do
    state = mount!()
    seat = fresh_free_seat!()
    seated = press(%{state | pos: {seat.x, seat.y}}, "s")
    assert seated.seated?

    {:noreply, after_say} = Theatre.handle_info({:say, "hi"}, seated)
    assert after_say.feed != []

    stood = press(after_say, " ")
    refute stood.seated?
    assert stood.feed == []
    assert stood.hint == nil
    assert {:error, _} = Lobby.seat_of(state.attendee.id)
  end

  test "unseated + space is a no-op" do
    state = mount!()
    assert press(state, " ") == state
  end

  test "seated + \"s\" hints to stand instead of re-claiming" do
    state = mount!()
    seat = fresh_free_seat!()
    seated = press(%{state | pos: {seat.x, seat.y}}, "s")

    {:ok, held_before} = Lobby.seat_of(state.attendee.id)

    hinted = press(seated, "s")
    assert hinted.seated?
    assert hinted.hint =~ "press space to stand"

    {:ok, held_after} = Lobby.seat_of(state.attendee.id)
    assert held_before.id == held_after.id
  end

  test "unknown keys are ignored" do
    state = mount!()
    assert press(state, "z") == state
  end

  test "\"q\" stops the session only when quit? is set" do
    quittable = mount!(quit?: true)
    assert {:stop, _state} = Theatre.handle_event(%Key{code: "q", kind: "press"}, quittable)

    not_quittable = mount!()

    assert {:noreply, ^not_quittable} =
             Theatre.handle_event(%Key{code: "q", kind: "press"}, not_quittable)
  end
end
