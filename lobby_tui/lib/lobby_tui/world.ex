defmodule LobbyTui.World do
  @moduledoc """
  The fixed 176×96 world grid (sprite scale: a 12×12px avatar spans 12 cols × 6 cell rows): border walls, a stage band at the bottom, ten rows of eight seats above it, and the lobby carpet at the far end. Purely static — all functions are deterministic lookups used by `Theatre` (render, movement), by the scene painter, and by seat seeding.

  ## Which way the room faces

  The stage is at the *bottom*. Seat art is drawn back-at-top,
  base-at-bottom, so a seat reads as facing down the screen; with the
  stage above them the whole audience appeared to have turned its back on
  the show. Everything is laid out from the stage upwards instead: apron,
  walkway, then row 1 (the front row, nearest the stage) climbing to row
  10 at the back, and the lobby carpet last of all. Attendees spawn in the
  walkway right at the apron, so the front rows fill first and the carpet
  is somewhere to walk to rather than the place everyone lands.

  ## Seats are footprints, not points

  Each seat has one anchor cell, but it is *painted* as a 12 col × 5 row
  block, and the whole block is sittable. Anchoring alone used to mean 60
  cells looked like a seat while exactly one accepted `s` — a 1.7% hit
  rate with nothing on screen marking the live cell. `seat_at/1` therefore
  resolves any cell of the block to its seat, and `Theatre` snaps the
  attendee onto the anchor when they sit, so seated avatars line up and
  the reserved-chair wash keeps a single known anchor to paint around.

  `footprint_offsets/0` is the one definition of that block. The scene
  painter derives its rectangle from it rather than restating the numbers,
  because the two drifting apart is precisely what makes a seat look
  sittable where it is not.

  Footprints tile with two-column and two-row gutters between them, so no
  cell ever belongs to two seats.
  """

  @width 176
  @height 96

  # Bottom-up bands. The apron is the stage's leading edge and so sits at
  # the top of the stage band, facing the house.
  @stage_rows 82..93
  @apron_rows 82..83
  @walkway_rows 80..81
  @lobby_rows 2..11

  # Cell offsets from a seat anchor to the block painted around it: 12
  # columns centred (slightly left-biased) on the anchor, and 5 rows rising
  # from the anchor's own row.
  @footprint_dx -6..5
  @footprint_dy -4..0

  # Columns come from the original twelve-column lattice at a 14-column
  # pitch, minus the two outermost and the two flanking the centre. What
  # they leave behind is four seats per block and three proper carpeted
  # aisles — a house, rather than a wall of chairs edge to edge.
  @lattice_origin 10
  @lattice_pitch 14
  @kept_lattice_columns [2, 3, 4, 5, 8, 9, 10, 11]
  @seat_x Enum.map(@kept_lattice_columns, &(@lattice_origin + (&1 - 1) * @lattice_pitch))

  # Row 1 is the front row, hard against the walkway; rows climb away from
  # the stage from there.
  @front_row_y 79
  @row_pitch 7
  @row_count 10

  @seats (for {x, index} <- Enum.with_index(@seat_x), row <- 1..@row_count do
            %{row: row, col: index + 1, x: x, y: @front_row_y - (row - 1) * @row_pitch}
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
  def seats, do: @seats

  @doc "Cell rows of the stage band, apron included. Not walkable."
  def stage_rows, do: @stage_rows

  @doc "Cell rows of the stage's leading edge, at the top of the band."
  def apron_rows, do: @apron_rows

  @doc "Cell rows of the lobby carpet, at the far end of the house from the stage."
  def lobby_rows, do: @lobby_rows

  @doc """
  The centre of the walkway at the foot of the stage: where an attendee stands until they connect (see `spawn_point/1`), and the fallback when the walkway is full.

  Deliberately not the lobby carpet. Landing at the far end meant the back
  rows filled first and the stage was a long walk away; landing at the
  apron puts the front rows within a step and makes the carpet somewhere
  to wander off to.
  """
  def spawn_point, do: {div(@width, 2), @walkway_rows.last}

  # Kept half a sprite in from the side walls, so nobody arrives with their
  # avatar cut off by the wall.
  @spawn_margin 6
  @spawn_cells for y <- @walkway_rows,
                   x <- (1 + @spawn_margin)..(@width - 2 - @spawn_margin),
                   do: {x, y}

  @spawn_candidates 12

  @doc """
  Where a newly connected attendee appears, given the cells everyone else is standing on: somewhere along the walkway, away from the others there.

  A whole audience joins from the same QR code within a minute, and one spawn cell piled them all into a single heap at the centre. Instead this takes a dozen random free cells along the walkway and keeps the one with the most columns between it and its nearest neighbour (columns only: the walkway is two rows and a sprite is six tall, so rows give no room). The walkway fits about fourteen avatars side by side, so a full house still overlaps, just evenly. With no free cell left it falls back to `spawn_point/0`.
  """
  def spawn_point(taken) do
    taken = MapSet.new(taken)
    neighbours = for {x, y} <- taken, y in @walkway_rows, do: x

    case Enum.reject(@spawn_cells, &MapSet.member?(taken, &1)) do
      [] ->
        spawn_point()

      free ->
        free |> Enum.take_random(@spawn_candidates) |> Enum.max_by(&clearance(&1, neighbours))
    end
  end

  defp clearance(_cell, []), do: 0
  defp clearance({x, _y}, neighbours), do: neighbours |> Enum.map(&abs(&1 - x)) |> Enum.min()

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
      y in @stage_rows -> :stage
      Map.has_key?(@seat_footprint_index, {x, y}) -> :seat
      true -> :floor
    end
  end

  def tile_at(_out_of_bounds), do: :wall

  def walkable?(pos), do: tile_at(pos) in [:floor, :seat]
end
