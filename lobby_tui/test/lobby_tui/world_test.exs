defmodule LobbyTui.WorldTest do
  use ExUnit.Case, async: true

  alias LobbyTui.World

  test "dimensions are 60x30" do
    assert World.width() == 60
    assert World.height() == 30
  end

  test "borders are walls, interior floor is walkable" do
    assert World.tile_at({0, 0}) == :wall
    assert World.tile_at({59, 29}) == :wall
    refute World.walkable?({0, 15})
    assert World.tile_at({30, 27}) == :floor
    assert World.walkable?({30, 27})
  end

  test "stage band is not walkable" do
    assert World.tile_at({30, 2}) == :stage
    refute World.walkable?({30, 2})
  end

  test "there are 120 seats in 10 rows of 12, and seats are walkable" do
    seats = World.seats()
    assert length(seats) == 120
    assert Enum.count(seats, &(&1.row == 1)) == 12
    first = Enum.find(seats, &(&1.row == 1 and &1.col == 1))
    assert %{x: 5, y: 6} = first
    assert World.tile_at({5, 6}) == :seat
    assert World.walkable?({5, 6})
  end

  test "seat_at finds a seat by position and nil elsewhere" do
    assert %{row: 1, col: 2} = World.seat_at({9, 6})
    assert World.seat_at({30, 27}) == nil
  end

  test "out of bounds is not walkable" do
    refute World.walkable?({-1, 5})
    refute World.walkable?({60, 5})
  end

  test "spawn point is walkable floor in the lobby band" do
    assert World.spawn_point() == {30, 27}
    assert World.walkable?(World.spawn_point())
  end
end
