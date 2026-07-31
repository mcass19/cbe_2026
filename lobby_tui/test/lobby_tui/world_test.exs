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
    # anchors: x = 10 + (col - 1) * 14, y = 20 + (row - 1) * 7
    first = Enum.find(seats, &(&1.row == 1 and &1.col == 1))
    assert %{x: 10, y: 20} = first
    second = Enum.find(seats, &(&1.row == 1 and &1.col == 2))
    assert %{x: 24, y: 20} = second
    assert World.tile_at({10, 20}) == :seat
    assert World.walkable?({10, 20})
  end

  test "seat_at finds a seat by position and nil elsewhere" do
    assert %{row: 1, col: 2} = World.seat_at({24, 18})
    assert World.seat_at({88, 88}) == nil
  end

  describe "seat footprints" do
    # The regression this guards: the seat used to be its anchor cell
    # alone, so 60 cells were painted as a seat and exactly one accepted
    # `s`. Every cell that looks like the seat must resolve to it.
    test "every cell of a seat's painted block resolves to that seat" do
      {dx_range, dy_range} = World.footprint_offsets()
      seat = Enum.find(World.seats(), &(&1.row == 6 and &1.col == 7))

      block = for dx <- dx_range, dy <- dy_range, do: {seat.x + dx, seat.y + dy}

      assert length(block) == 60

      for pos <- block do
        assert World.seat_at(pos) == seat, "expected #{inspect(pos)} to sit in #{inspect(seat)}"
        assert World.tile_at(pos) == :seat
        assert World.walkable?(pos)
      end
    end

    test "footprints never overlap, so no cell belongs to two seats" do
      {dx_range, dy_range} = World.footprint_offsets()

      cells =
        for seat <- World.seats(), dx <- dx_range, dy <- dy_range, do: {seat.x + dx, seat.y + dy}

      assert length(cells) == length(Enum.uniq(cells))
      assert length(cells) == 120 * 60
    end

    test "the gutters between footprints are plain floor" do
      seat = Enum.find(World.seats(), &(&1.row == 6 and &1.col == 7))
      {dx_range, dy_range} = World.footprint_offsets()

      # Two columns and two rows of clearance sit between adjacent blocks.
      assert World.seat_at({seat.x + dx_range.last + 1, seat.y}) == nil
      assert World.seat_at({seat.x, seat.y + 1}) == nil
      assert World.tile_at({seat.x, seat.y + 1}) == :floor
      assert World.seat_at({seat.x, seat.y + dy_range.first - 1}) == nil
    end

    test "a walkway separates the stage apron from the front row" do
      # Without it the front row butts straight against the apron and the
      # seated camera frames a wall of seats with no floor in front.
      assert World.tile_at({10, 13}) == :stage
      assert World.tile_at({10, 14}) == :floor
      assert World.tile_at({10, 15}) == :floor
      assert World.tile_at({10, 16}) == :seat
      assert World.walkable?({10, 14})
    end

    test "the back row clears the lobby band without overlapping it" do
      {_dx_range, dy_range} = World.footprint_offsets()
      back = Enum.find(World.seats(), &(&1.row == 10 and &1.col == 1))

      assert back.y + dy_range.last == 83
      assert World.tile_at({back.x, 84}) == :floor
    end

    test "the stage band still wins over anything that would reach into it" do
      assert World.tile_at({10, 2}) == :stage
      refute World.walkable?({10, 2})
    end

    test "seat_anchor resolves a seat's identity back to its current position" do
      for seat <- World.seats() do
        assert World.seat_anchor(seat.row, seat.col) == {seat.x, seat.y}
      end

      assert World.seat_anchor(99, 99) == nil
    end
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
