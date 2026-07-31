defmodule LobbyTui.World do
  @moduledoc """
  The fixed 176×96 world grid (sprite scale: a 12×12px avatar spans 12 cols × 6 cell rows): border walls, a stage band at the top, ten rows of twelve seats, and an open lobby band at the bottom. Purely static — all functions are deterministic lookups used by `Theatre` (render, movement) and by seat seeding.

  ## Seats are footprints, not points

  Each seat has one anchor cell, but it is *painted* as a 12 col × 5 row
  block, and the whole block is sittable. Anchoring alone used to mean 60
  cells looked like a seat while exactly one accepted `s` — a 1.7% hit
  rate with nothing on screen marking the live cell. `seat_at/1` therefore
  resolves any cell of the block to its seat, and `Theatre` snaps the
  attendee onto the anchor when they sit, so seated avatars line up and
  the occupancy tint keeps a single known cell to paint.

  `footprint_offsets/0` is the one definition of that block. The scene
  painter derives its rectangle from it rather than restating the numbers,
  because the two drifting apart is precisely what makes a seat look
  sittable where it is not.

  Footprints tile with two-column and two-row gutters between them, so no
  cell ever belongs to two seats.
  """

  @width 176
  @height 96

  # Cell offsets from a seat anchor to the block painted around it: 12
  # columns centred (slightly left-biased) on the anchor, and 5 rows rising
  # from the anchor's own row.
  @footprint_dx -6..5
  @footprint_dy -4..0

  # Row 1's footprint starts two rows below the stage apron (which ends at
  # row 13) rather than butting straight against it — a real house leaves
  # a walkway in front of the front row, and the seated camera frames the
  # stage with that gap and the first rows of seats in shot.
  @seats (for row <- 1..10, col <- 1..12 do
            %{row: row, col: col, x: 10 + (col - 1) * 14, y: 20 + (row - 1) * 7}
          end)

  @seat_footprint_index (for seat <- @seats,
                             dx <- @footprint_dx,
                             dy <- @footprint_dy,
                             into: %{} do
                           {{seat.x + dx, seat.y + dy}, seat}
                         end)

  @seat_by_row_col Map.new(@seats, &{{&1.row, &1.col}, &1})

  def width, do: @width
  def height, do: @height
  def spawn_point, do: {88, 88}
  def seats, do: @seats

  @doc """
  The `{dx_range, dy_range}` cell offsets of a seat's painted block,
  relative to its anchor. Consumed by `LobbyTui.Scripts.PlaceholderScene`
  so the art and the hitbox cannot disagree.
  """
  def footprint_offsets, do: {@footprint_dx, @footprint_dy}

  @doc """
  The seat whose painted block contains `pos`, or nil. Any cell of the
  block resolves to the same seat; the returned map's `:x`/`:y` are the
  anchor, which is where a sitting attendee is placed.
  """
  def seat_at(pos), do: Map.get(@seat_footprint_index, pos)

  @doc """
  The anchor cell of the seat at `{row, col}`, or nil.

  `{row, col}` is a seat's identity and never moves; its coordinates are
  geometry and do move. Seat records are seeded into ETS at boot, so
  anything that reads a persisted `x`/`y` is reading a snapshot of the
  world as it was at seed time. Callers holding a seat record should come
  back through here for its position rather than trust the stored pair.
  """
  def seat_anchor(row, col) do
    case Map.fetch(@seat_by_row_col, {row, col}) do
      {:ok, %{x: x, y: y}} -> {x, y}
      :error -> nil
    end
  end

  def tile_at({x, y}) when x in [0, @width - 1] or y in [0, @height - 1], do: :wall

  def tile_at({x, y}) when x > 0 and x < @width - 1 and y > 0 and y < @height - 1 do
    cond do
      y in 2..13 -> :stage
      Map.has_key?(@seat_footprint_index, {x, y}) -> :seat
      true -> :floor
    end
  end

  def tile_at(_out_of_bounds), do: :wall

  def walkable?(pos), do: tile_at(pos) in [:floor, :seat]
end
