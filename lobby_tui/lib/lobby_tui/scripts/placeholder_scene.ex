defmodule LobbyTui.Scripts.PlaceholderScene do
  @moduledoc """
  Paints the theatre background as one PNG — the "midnight house": quiet
  slate floorboards, individual plum velvet chairs with brass armrest caps
  at the exact `LobbyTui.World` seat anchors, violet aisle runners with
  piping and a diamond motif, the lobby carpet at the top, and along the
  bottom a stage whose gold-lipped apron is the brightest thing in the
  room, under a fold-shaded curtain with a tasseled valance. Every band
  and anchor is read from `World`, so geometry can never drift from the
  hitboxes.

  Cell rows are two pixels tall (the renderer collapses each pair into one
  half-block cell), so every band converts as `cell × 2`.

  Invoked by `priv/scripts/gen_placeholder_scene.exs`; lives in `lib/` (not
  inline in the script) so `palette/0` is available to `LobbyTui.SceneTest`
  without re-running the paint as a side effect of loading the test.
  """

  alias LobbyTui.World

  @width 176
  @height 192

  @px_per_cell_row 2

  # Bands, converted from `World`'s cell rows. Nothing here restates a
  # number the world already owns.
  @stage_top World.stage_rows().first * @px_per_cell_row
  @stage_bottom World.stage_rows().last * @px_per_cell_row + 1
  @apron_top World.apron_rows().first * @px_per_cell_row
  @apron_bottom World.apron_rows().last * @px_per_cell_row + 1
  @lobby_top World.lobby_rows().first * @px_per_cell_row
  @lobby_bottom World.lobby_rows().last * @px_per_cell_row + 1

  # Wall trim: a band top and bottom plus both side margins, 4 px each.
  @trim_rows_top 0..3
  @trim_rows_bottom (@height - 4)..(@height - 1)
  @trim_cols_left 0..3
  @trim_cols_right (@width - 4)..(@width - 1)

  # The chair is drawn inside the seat footprint with one column of
  # breathing room on each side, so neighbouring chairs never touch.
  {dx_range, dy_range} = World.footprint_offsets()
  @seat_dx dx_range
  @seat_px_height Range.size(dy_range) * @px_per_cell_row

  # Anything wider than a between-seat gutter counts as an aisle.
  @min_aisle_width 8

  # Valance: rows of drape hanging from the apron lip, ending in a fringe
  # line with a tassel knot every few columns.
  @valance_depth 3
  @tassel_pitch 8

  # The midnight palette.
  @wall {22, 21, 30}
  @wall_lo {18, 17, 25}
  @floor {45, 40, 52}
  @floor_seam {36, 32, 42}
  @floor_hi {52, 47, 60}
  @runner {66, 46, 82}
  @runner_edge {48, 33, 60}
  @runner_gold {150, 120, 190}
  @runner_dot {57, 40, 71}
  @chair_back {108, 40, 72}
  @chair_back_hi {134, 56, 92}
  @chair_back_lo {80, 28, 54}
  @chair_outline {38, 16, 30}
  @chair_cushion {90, 32, 60}
  @arm {150, 120, 190}
  @arm_lo {100, 78, 130}
  @curtain_folds [
    {96, 30, 64},
    {116, 40, 78},
    {140, 52, 94},
    {116, 40, 78},
    {96, 30, 64},
    {76, 22, 50},
    {62, 17, 42},
    {76, 22, 50}
  ]
  @curtain_shadow {62, 17, 42}
  @valance {62, 17, 42}
  @fringe {238, 180, 96}
  @apron {120, 84, 48}
  @apron_hi {160, 116, 64}
  @apron_lo {70, 48, 30}
  @lobby_floor {38, 36, 50}
  @lobby_pattern {31, 29, 41}
  @lobby_edge {50, 47, 66}

  @doc "The palette, exposed so tests can assert scene cells land on these colors."
  def palette do
    %{
      wall: @wall,
      wall_lo: @wall_lo,
      floor: @floor,
      floor_seam: @floor_seam,
      floor_hi: @floor_hi,
      runner: @runner,
      runner_edge: @runner_edge,
      runner_gold: @runner_gold,
      runner_dot: @runner_dot,
      chair_back: @chair_back,
      chair_back_hi: @chair_back_hi,
      chair_back_lo: @chair_back_lo,
      chair_outline: @chair_outline,
      chair_cushion: @chair_cushion,
      arm: @arm,
      arm_lo: @arm_lo,
      curtain_folds: Enum.uniq(@curtain_folds),
      curtain_shadow: @curtain_shadow,
      valance: @valance,
      fringe: @fringe,
      apron: @apron,
      apron_hi: @apron_hi,
      apron_lo: @apron_lo,
      lobby_floor: @lobby_floor,
      lobby_pattern: @lobby_pattern,
      lobby_edge: @lobby_edge
    }
  end

  def default_path, do: Path.join([:code.priv_dir(:lobby_tui), "scene", "theatre.png"])

  def run(dest \\ default_path()) do
    chairs = chair_pixel_map()
    aisles = aisle_pixel_map()

    canvas =
      for y <- 0..(@height - 1) do
        for x <- 0..(@width - 1) do
          {r, g, b} = color_at(x, y, chairs, aisles)
          ExPng.Color.rgb(r, g, b)
        end
      end

    File.mkdir_p!(Path.dirname(dest))
    image = ExPng.Image.new(canvas)
    {:ok, ^dest} = ExPng.Image.to_file(image, dest)
    IO.puts("wrote #{dest}")
    dest
  end

  defp color_at(x, y, chairs, aisles) do
    cond do
      trim?(x, y) -> wall_color(x, y)
      y in @stage_top..@stage_bottom -> stage_color(x, y)
      y in @lobby_top..@lobby_bottom -> lobby_color(x, y)
      Map.has_key?(chairs, {x, y}) -> Map.fetch!(chairs, {x, y})
      Map.has_key?(aisles, {x, y}) -> Map.fetch!(aisles, {x, y})
      true -> floor_color(y)
    end
  end

  defp trim?(x, y) do
    y in @trim_rows_top or y in @trim_rows_bottom or
      x in @trim_cols_left or x in @trim_cols_right
  end

  defp wall_color(x, y) do
    if rem(x + y, 2) == 0, do: @wall, else: @wall_lo
  end

  # Quiet horizontal boards: a seam every 6 px, one soft highlight line in
  # every other board.
  defp floor_color(y) do
    cond do
      rem(y, 6) == 0 -> @floor_seam
      rem(y, 12) == 3 -> @floor_hi
      true -> @floor
    end
  end

  # -- stage ---------------------------------------------------------------

  defp stage_color(_x, y) when y in @apron_top..@apron_bottom do
    cond do
      y == @apron_top -> @fringe
      y == @apron_top + 1 -> @apron_hi
      y == @apron_bottom -> @apron_lo
      true -> @apron
    end
  end

  defp stage_color(x, y) do
    valance_bottom = @apron_bottom + @valance_depth + 1

    cond do
      y <= @apron_bottom + @valance_depth -> @valance
      y == valance_bottom -> @fringe
      y == valance_bottom + 1 and tassel?(x) -> @fringe
      x in (@trim_cols_left.last + 1)..(@trim_cols_left.last + 2) -> @curtain_shadow
      x in (@trim_cols_right.first - 2)..(@trim_cols_right.first - 1) -> @curtain_shadow
      true -> Enum.at(@curtain_folds, rem(x - @trim_cols_left.last - 1, length(@curtain_folds)))
    end
  end

  defp tassel?(x) do
    rem(x - @trim_cols_left.last - 1 - div(@tassel_pitch, 2), @tassel_pitch) == 0
  end

  # -- lobby ---------------------------------------------------------------

  defp lobby_color(x, y) do
    cond do
      y == @lobby_bottom -> @lobby_edge
      y == @lobby_bottom - 1 -> @lobby_pattern
      rem(div(x, 4) + div(y, 4), 2) == 0 and (rem(x, 4) == 0 or rem(y, 4) == 0) -> @lobby_pattern
      true -> @lobby_floor
    end
  end

  # -- chairs --------------------------------------------------------------

  defp chair_pixel_map do
    World.seats()
    |> Enum.flat_map(&chair_pixels/1)
    |> Map.new()
  end

  # One plum chair per seat anchor, drawn inside the footprint with a 1 px
  # gap each side: a rounded back panel with highlight and shade, a cushion
  # row between brass armrest caps, and an outlined base with two feet.
  defp chair_pixels(%{x: x, y: y}) do
    bottom = y * @px_per_cell_row + 1
    top = bottom - @seat_px_height + 1
    left = x + @seat_dx.first + 1
    right = x + @seat_dx.last - 1

    back =
      for py <- top..(top + 5), px <- left..right do
        {{px, py}, back_pixel(px, py, left, right, top)}
      end

    cushion =
      for py <- (top + 6)..(top + 7), px <- left..right do
        {{px, py}, cushion_pixel(px, py, left, right, top)}
      end

    base =
      for px <- (left + 1)..(right - 1) do
        {{px, top + 8}, @chair_outline}
      end

    feet = [{{left + 1, bottom}, @arm_lo}, {{right - 1, bottom}, @arm_lo}]

    # Rounded top: the back's corner pixels stay unpainted, falling through
    # to the floor.
    corners = [{left, top}, {right, top}]

    (back ++ cushion ++ base ++ feet)
    |> Enum.reject(fn {pos, _color} -> pos in corners end)
  end

  defp back_pixel(px, py, left, right, top) do
    cond do
      py == top -> @chair_outline
      px in [left, right] -> @chair_outline
      py == top + 1 and px in (left + 2)..(right - 2) -> @chair_back_hi
      py == top + 5 -> @chair_back_lo
      true -> @chair_back
    end
  end

  defp cushion_pixel(px, py, left, right, top) do
    cond do
      px in [left, right] -> @arm
      py == top + 7 -> @chair_back_lo
      true -> @chair_cushion
    end
  end

  # -- aisles --------------------------------------------------------------

  # Runner carpet over every aisle run: darker selvedge on the outer
  # columns, a line of brass piping just inside, and a diamond knot down
  # the middle every few rows.
  defp aisle_pixel_map do
    aisle_columns()
    |> runs()
    |> Enum.flat_map(&runner_pixels/1)
    |> Map.new()
  end

  defp runner_pixels(cols) do
    first = List.first(cols)
    last = List.last(cols)
    center = div(first + last, 2)

    field =
      for x <- cols, y <- (@lobby_bottom + 1)..(@stage_top - 1) do
        {{x, y}, runner_pixel(x, {first, last}, {center, y})}
      end

    field
  end

  defp runner_pixel(x, {first, last}, {center, y}) do
    cond do
      x in [first, last] -> @runner_edge
      x in [first + 1, last - 1] -> @runner_gold
      diamond?(x, y, center) -> @runner_dot
      true -> @runner
    end
  end

  # A 5-pixel diamond centred on the runner every 8 rows.
  defp diamond?(x, y, center) do
    abs(x - center) + abs(rem(y, 8) - 4) <= 1
  end

  @doc """
  Columns carpeted as aisles: every run of interior columns no seat block
  covers that is wider than the two-column gutter between neighbouring
  seats. Derived rather than hardcoded, so dropping or adding a column of
  seats re-carpets the room by itself.
  """
  def aisle_columns do
    {dx, _dy} = World.footprint_offsets()

    covered =
      for %{x: x} <- World.seats(), col <- (x + dx.first)..(x + dx.last), into: MapSet.new() do
        col
      end

    (@trim_cols_left.last + 1)..(@trim_cols_right.first - 1)//1
    |> Enum.reject(&MapSet.member?(covered, &1))
    |> consecutive_runs()
    |> Enum.filter(&(length(&1) >= @min_aisle_width))
    |> List.flatten()
    |> MapSet.new()
  end

  defp runs(col_set) do
    col_set
    |> Enum.sort()
    |> consecutive_runs()
  end

  defp consecutive_runs(cols) do
    cols
    |> Enum.sort()
    |> Enum.chunk_while(
      [],
      fn col, acc ->
        case acc do
          [] -> {:cont, [col]}
          [prev | _] when col == prev + 1 -> {:cont, [col | acc]}
          _ -> {:cont, Enum.reverse(acc), [col]}
        end
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
  end
end
