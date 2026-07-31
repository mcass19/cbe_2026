defmodule LobbyTui.Scripts.PlaceholderScene do
  @moduledoc """
  Paints the theatre background as one PNG: wall trim, the lobby carpet at
  the top, a dithered auditorium floor with wooden seat blocks at the exact
  `LobbyTui.World` seat anchors, carpeted aisles between the seat blocks,
  and the curtained stage along the bottom. Placeholder art — simple
  rectangles and dithering, replaced later by an Aseprite painting with
  zero code change, since every band and anchor here is read from `World`.

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

  # The carpet's dithered edge faces the seats, so it sits at the band's
  # lower edge now that the lobby is at the top of the map.
  @lobby_dither_rows (@lobby_bottom - 3)..@lobby_bottom

  # Wall trim: a band top and bottom plus both side margins, 4 px each.
  @trim_rows_top 0..3
  @trim_rows_bottom (@height - 4)..(@height - 1)
  @trim_cols_left 0..3
  @trim_cols_right (@width - 4)..(@width - 1)

  # Seat rectangle, derived from `World.footprint_offsets/0` rather than
  # restated here: the block the painter draws and the block `seat_at/1`
  # accepts must be the same block, or seats look sittable where they are
  # not. The footprint's 5 cell rows are 10 px — an 8 px back above a 2 px
  # base, the base bottom-aligned to the anchor row's own band.
  {dx_range, dy_range} = World.footprint_offsets()
  @seat_dx dx_range
  @seat_base_height 2
  @seat_back_height Range.size(dy_range) * @px_per_cell_row - @seat_base_height

  # Anything wider than a between-seat gutter counts as an aisle.
  @min_aisle_width 8

  @slate {70, 74, 82}
  @curtain_a {170, 35, 35}
  @curtain_b {140, 22, 22}
  @apron_color {80, 14, 14}
  @floor_a {112, 82, 56}
  @floor_b {92, 66, 44}
  @seat_back {120, 80, 45}
  @seat_base {60, 38, 20}
  @aisle_red {172, 40, 40}
  @lobby_floor {55, 50, 48}
  @lobby_dither {40, 36, 34}

  @doc "The palette, exposed so tests can assert scene cells land on these colors."
  def palette do
    %{
      slate: @slate,
      curtain_a: @curtain_a,
      curtain_b: @curtain_b,
      apron: @apron_color,
      floor_a: @floor_a,
      floor_b: @floor_b,
      seat_back: @seat_back,
      seat_base: @seat_base,
      aisle: @aisle_red,
      lobby_floor: @lobby_floor,
      lobby_dither: @lobby_dither
    }
  end

  def default_path, do: Path.join([:code.priv_dir(:lobby_tui), "scene", "theatre.png"])

  def run(dest \\ default_path()) do
    seat_pixels = seat_pixel_map()
    aisles = aisle_columns()

    canvas =
      for y <- 0..(@height - 1) do
        for x <- 0..(@width - 1) do
          {r, g, b} = color_at(x, y, seat_pixels, aisles)
          ExPng.Color.rgb(r, g, b)
        end
      end

    File.mkdir_p!(Path.dirname(dest))
    image = ExPng.Image.new(canvas)
    {:ok, ^dest} = ExPng.Image.to_file(image, dest)
    IO.puts("wrote #{dest}")
    dest
  end

  defp color_at(x, y, seat_pixels, aisles) do
    cond do
      trim?(x, y) -> @slate
      y in @stage_top..@stage_bottom -> stage_color(x, y)
      y in @lobby_top..@lobby_bottom -> lobby_color(x, y)
      Map.has_key?(seat_pixels, {x, y}) -> Map.fetch!(seat_pixels, {x, y})
      MapSet.member?(aisles, x) -> @aisle_red
      true -> floor_color(x, y)
    end
  end

  defp trim?(x, y) do
    y in @trim_rows_top or y in @trim_rows_bottom or
      x in @trim_cols_left or x in @trim_cols_right
  end

  defp stage_color(_x, y) when y in @apron_top..@apron_bottom, do: @apron_color

  defp stage_color(x, _y) do
    if rem(div(x, 4), 2) == 0, do: @curtain_a, else: @curtain_b
  end

  defp lobby_color(x, y) when y in @lobby_dither_rows do
    if rem(div(x, 2) + div(y, 2), 2) == 0, do: @lobby_dither, else: @lobby_floor
  end

  defp lobby_color(_x, _y), do: @lobby_floor

  defp floor_color(x, y) do
    if rem(div(x, 2) + div(y, 2), 2) == 0, do: @floor_a, else: @floor_b
  end

  defp seat_pixel_map do
    World.seats()
    |> Enum.flat_map(&seat_pixels/1)
    |> Map.new()
  end

  # Seat anchor {x, y} (cell coords) -> px. The rectangle spans the
  # footprint's columns and its 2-px base sits exactly on the anchor row's
  # own px band, with the back rising above it.
  defp seat_pixels(%{x: x, y: y}) do
    left = x + @seat_dx.first
    right = x + @seat_dx.last
    base_bottom = y * @px_per_cell_row + 1
    base_top = base_bottom - @seat_base_height + 1
    back_bottom = base_top - 1
    back_top = back_bottom - @seat_back_height + 1

    base = for(py <- base_top..base_bottom, px <- left..right, do: {{px, py}, @seat_base})
    back = for(py <- back_top..back_bottom, px <- left..right, do: {{px, py}, @seat_back})
    base ++ back
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
