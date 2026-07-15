defmodule LobbyTui.WorldTest do
  use ExUnit.Case, async: true

  alias LobbyTui.World

  test "dimensions are 176x96" do
    assert World.width() == 176
    assert World.height() == 96
  end

  test "borders are walls, interior floor is walkable" do
    assert World.tile_at({0, 0}) == :wall
    assert World.tile_at({175, 95}) == :wall
    refute World.walkable?({0, 40})
    assert World.tile_at({88, 88}) == :floor
    assert World.walkable?({88, 88})
  end

  test "stage band is not walkable" do
    assert World.tile_at({30, 2}) == :stage
    assert World.tile_at({30, 13}) == :stage
    refute World.walkable?({30, 2})
    refute World.walkable?({30, 13})
  end

  test "there are 120 seats in 10 rows of 12, and seats are walkable" do
    seats = World.seats()
    assert length(seats) == 120
    assert Enum.count(seats, &(&1.row == 1)) == 12
    # anchors: x = 10 + (col - 1) * 14, y = 18 + (row - 1) * 7
    first = Enum.find(seats, &(&1.row == 1 and &1.col == 1))
    assert %{x: 10, y: 18} = first
    second = Enum.find(seats, &(&1.row == 1 and &1.col == 2))
    assert %{x: 24, y: 18} = second
    assert World.tile_at({10, 18}) == :seat
    assert World.walkable?({10, 18})
  end

  test "seat_at finds a seat by position and nil elsewhere" do
    assert %{row: 1, col: 2} = World.seat_at({24, 18})
    assert World.seat_at({88, 88}) == nil
  end

  test "out of bounds is not walkable" do
    refute World.walkable?({-1, 5})
    refute World.walkable?({176, 5})
  end

  test "spawn point is walkable floor in the lobby band" do
    assert World.spawn_point() == {88, 88}
    assert World.walkable?(World.spawn_point())
  end
end
