defmodule LobbyTui.Theatre.RenderTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Frame
  alias LobbyTui.Theatre.{Render, State}

  defp state do
    attendee = %LobbyTui.Lobby.Attendee{id: "self", nickname: "me", avatar_id: "av"}
    State.new(attendee, {:rgb, 9, 9, 9})
  end

  test "camera clamps to world bounds" do
    # viewport 80x40 inside a 176x96 world; max_ox = 176 - 80 = 96, max_oy = 96 - 40 = 56
    # near top-left corner: ox = 5 - div(80, 2) = 5 - 40 = -35 -> clamped to 0
    #                       oy = 5 - div(40, 2) = 5 - 20 = -15 -> clamped to 0
    assert Render.camera({5, 5}, 80, 40) == {0, 0}
    # near bottom-right corner: ox = 170 - 40 = 130 -> clamped to max_ox 96
    #                           oy = 90 - 20 = 70 -> clamped to max_oy 56
    assert Render.camera({170, 90}, 80, 40) == {96, 56}
    # centered, no clamping needed: ox = 90 - 40 = 50 (in 0..96); oy = 50 - 20 = 30 (in 0..56)
    assert Render.camera({90, 50}, 80, 40) == {50, 30}
  end

  test "camera centered on a full-world viewport is the origin" do
    # viewport equals world size (176x96); max_ox = max_oy = 0 regardless of pos
    assert Render.camera({88, 48}, 176, 96) == {0, 0}
  end

  test "world lines mark self, seats, walls, and stage" do
    lines = Render.world_lines(state(), 176, 96)
    assert length(lines) == 96
    assert length(hd(lines).spans) == 176

    row = fn y -> Enum.at(lines, y) end
    cell = fn y, x -> Enum.at(row.(y).spans, x) end

    assert cell.(0, 0).content == "█"
    # stage band is now cell rows 2..13
    assert cell.(2, 30).content == "░"
    # first seat anchor: x = 10 + (1 - 1) * 14 = 10, y = 18 + (1 - 1) * 7 = 18
    assert cell.(18, 10).content == "▪"
    {sx, sy} = LobbyTui.World.spawn_point()
    assert cell.(sy, sx).content == "@"
    assert cell.(sy, sx).style.fg == {:rgb, 9, 9, 9}
  end

  test "another attendee's indexed position renders as ☻" do
    other = %{
      state()
      | others_by_pos: %{{10, 10} => %{nickname: "o", color: :cyan, x: 10, y: 10}}
    }

    lines = Render.world_lines(other, 176, 96)
    cell = lines |> Enum.at(10) |> Map.fetch!(:spans) |> Enum.at(10)
    assert cell.content == "☻"
    assert cell.style.fg == :cyan
  end

  test "occupied seats render differently from free seats" do
    # seat row 1: col 1 anchor {10, 18}, col 2 anchor {24, 18}
    occupied = %{state() | occupied: %{{10, 18} => "someone"}}
    lines = Render.world_lines(occupied, 176, 96)
    taken = lines |> Enum.at(18) |> Map.fetch!(:spans) |> Enum.at(10)
    free = lines |> Enum.at(18) |> Map.fetch!(:spans) |> Enum.at(24)
    assert taken.style.fg != free.style.fg
  end

  test "widgets: world only when unseated, world + feed panel when seated" do
    frame = %Frame{width: 60, height: 40}
    assert [{_world, _rect}, {_status, _}] = Render.widgets(state(), frame)

    seated = %{state() | seated?: true}
    assert [{_world, _}, {_feed, _}, {_status, _}] = Render.widgets(seated, frame)
  end

  test "hint appears in the status line" do
    lined = %{state() | hint: "seat taken — try another"}
    frame = %Frame{width: 60, height: 40}
    [_world, {status, _rect}] = Render.widgets(lined, frame)
    assert status.text =~ "seat taken"
  end
end
