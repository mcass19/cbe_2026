defmodule LobbyTui.WorldTest do
  use ExUnit.Case, async: true

  alias LobbyTui.World

  # Positions are derived from World rather than written out, so a
  # re-layout changes one module instead of cascading through the suite.
  # What is asserted is the *shape* of the room: which band is where,
  # what is walkable, and that the seat lattice holds together.

  defp front_row, do: Enum.filter(World.seats(), &(&1.row == 1))
  defp back_row, do: Enum.filter(World.seats(), &(&1.row == 10))
  defp a_seat, do: Enum.find(World.seats(), &(&1.row == 4 and &1.col == 3))

  test "dimensions are 176x96" do
    assert World.width() == 176
    assert World.height() == 96
  end

  test "borders are walls" do
    assert World.tile_at({0, 0}) == :wall
    assert World.tile_at({175, 95}) == :wall
    refute World.walkable?({0, 40})
  end

  test "out of bounds is not walkable" do
    refute World.walkable?({-1, 5})
    refute World.walkable?({176, 5})
  end

  describe "which way the room faces" do
    # Seat art is drawn back-at-top, base-at-bottom, so seats read as
    # facing down the screen. The stage has to be below them or the whole
    # audience appears to have turned its back on the show.
    test "the stage is along the bottom, below every seat" do
      lowest_seat = World.seats() |> Enum.map(& &1.y) |> Enum.max()

      assert World.stage_rows().first > lowest_seat
      assert World.stage_rows().last == World.height() - 3
    end

    test "the lobby carpet is at the far end, above every seat" do
      highest_seat = World.seats() |> Enum.map(& &1.y) |> Enum.min()

      assert World.lobby_rows().last < highest_seat
      assert World.lobby_rows().first < World.stage_rows().first
    end

    test "the stage band is not walkable" do
      for y <- [World.stage_rows().first, World.stage_rows().last] do
        assert World.tile_at({30, y}) == :stage
        refute World.walkable?({30, y})
      end
    end

    test "the lobby carpet is walkable floor, reachable on foot" do
      for y <- [World.lobby_rows().first, World.lobby_rows().last] do
        assert World.tile_at({88, y}) == :floor
        assert World.walkable?({88, y})
      end
    end
  end

  describe "spawn" do
    test "attendees appear in the walkway at the apron, not on the lobby carpet" do
      {x, y} = World.spawn_point()

      assert World.walkable?(World.spawn_point())
      assert World.tile_at(World.spawn_point()) == :floor
      assert x == div(World.width(), 2)

      # Between the front row and the stage: one step from a seat, and a
      # long way from the carpet.
      assert y < World.stage_rows().first
      assert y > Enum.map(front_row(), & &1.y) |> Enum.max()
      refute y in World.lobby_rows()
    end
  end

  describe "the seat lattice" do
    test "eighty seats in ten rows of eight, all walkable" do
      seats = World.seats()

      assert length(seats) == 80
      assert seats |> Enum.map(& &1.row) |> Enum.uniq() |> length() == 10
      assert seats |> Enum.map(& &1.col) |> Enum.uniq() |> length() == 8
      assert Enum.count(seats, &(&1.row == 1)) == 8

      for seat <- seats do
        assert World.tile_at({seat.x, seat.y}) == :seat
        assert World.walkable?({seat.x, seat.y})
      end
    end

    test "row 1 is the front row, nearest the stage, and rows climb away from it" do
      by_row = Enum.group_by(World.seats(), & &1.row, & &1.y)

      ys = for row <- 1..10, do: by_row |> Map.fetch!(row) |> Enum.uniq() |> hd()

      assert ys == Enum.sort(ys, :desc), "row numbers should climb away from the stage"
    end

    test "seats form two blocks of four with a wide carpeted aisle between" do
      cols = World.seats() |> Enum.map(& &1.x) |> Enum.uniq() |> Enum.sort()
      gaps = cols |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)

      # Seven gaps: six at the regular lattice pitch, one much larger
      # where the two centre columns were removed for the aisle.
      assert length(gaps) == 7
      assert Enum.count(gaps, &(&1 > Enum.min(gaps))) == 1
    end

    test "seat_at finds a seat by position and nil off the lattice" do
      seat = a_seat()

      assert World.seat_at({seat.x, seat.y}) == seat
      assert World.seat_at(World.spawn_point()) == nil
      assert World.seat_at({88, World.lobby_rows().first}) == nil
    end

    test "seat_anchor resolves a seat's identity back to its current position" do
      for seat <- World.seats() do
        assert World.seat_anchor(seat.row, seat.col) == {seat.x, seat.y}
      end

      assert World.seat_anchor(99, 99) == nil
    end
  end

  describe "seat footprints" do
    # The regression this guards: the seat used to be its anchor cell
    # alone, so 60 cells were painted as a seat and exactly one accepted
    # `s`. Every cell that looks like the seat must resolve to it.
    test "every cell of a seat's painted block resolves to that seat" do
      {dx_range, dy_range} = World.footprint_offsets()
      seat = a_seat()

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
      assert length(cells) == 80 * 60
    end

    test "a walkway separates the stage apron from the front row" do
      {_dx_range, dy_range} = World.footprint_offsets()
      front_edge = front_row() |> Enum.map(&(&1.y + dy_range.last)) |> Enum.max()

      walkway = (front_edge + 1)..(World.stage_rows().first - 1)

      assert Range.size(walkway) == 2

      for y <- walkway do
        assert World.tile_at({88, y}) == :floor
        assert World.walkable?({88, y})
      end
    end

    test "the back row clears the lobby carpet without overlapping it" do
      {_dx_range, dy_range} = World.footprint_offsets()
      back_edge = back_row() |> Enum.map(&(&1.y + dy_range.first)) |> Enum.min()

      assert back_edge > World.lobby_rows().last
    end
  end
end
