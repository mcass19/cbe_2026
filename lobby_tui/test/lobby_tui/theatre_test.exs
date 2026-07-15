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

  test "seated + arrow key does not move, hints to stand" do
    state = mount!()
    seat = fresh_free_seat!()
    seated = press(%{state | pos: {seat.x, seat.y}}, "s")
    assert seated.seated?

    moved = press(seated, "up")
    assert moved.pos == seated.pos
    assert moved.hint =~ "press space to stand"
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
