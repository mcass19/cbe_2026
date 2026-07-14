defmodule LobbyTui.Theatre.RenderTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Frame
  alias LobbyTui.Theatre.{Render, State}

  defp state do
    attendee = %LobbyTui.Lobby.Attendee{id: "self", nickname: "me", avatar_id: "av"}
    State.new(attendee, {:rgb, 9, 9, 9})
  end

  test "camera clamps to world bounds" do
    assert Render.camera({2, 2}, 30, 20) == {0, 0}
    assert Render.camera({58, 28}, 30, 20) == {30, 10}
    assert Render.camera({30, 15}, 30, 20) == {15, 5}
  end

  test "camera centered on a full-world viewport is the origin" do
    assert Render.camera({30, 15}, 60, 30) == {0, 0}
  end

  test "world lines mark self, seats, walls, and stage" do
    lines = Render.world_lines(state(), 60, 30)
    assert length(lines) == 30
    assert length(hd(lines).spans) == 60

    row = fn y -> Enum.at(lines, y) end
    cell = fn y, x -> Enum.at(row.(y).spans, x) end

    assert cell.(0, 0).content == "█"
    assert cell.(2, 30).content == "░"
    assert cell.(6, 5).content == "▪"
    {sx, sy} = LobbyTui.World.spawn_point()
    assert cell.(sy, sx).content == "@"
    assert cell.(sy, sx).style.fg == {:rgb, 9, 9, 9}
  end

  test "occupied seats render differently from free seats" do
    occupied = %{state() | occupied: %{{5, 6} => "someone"}}
    lines = Render.world_lines(occupied, 60, 30)
    taken = lines |> Enum.at(6) |> Map.fetch!(:spans) |> Enum.at(5)
    free = lines |> Enum.at(6) |> Map.fetch!(:spans) |> Enum.at(9)
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
