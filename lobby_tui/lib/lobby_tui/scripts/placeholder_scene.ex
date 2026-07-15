defmodule LobbyTui.Scripts.PlaceholderScene do
  @moduledoc """
  Paints the theatre background as one PNG: wall trim, a curtained stage
  band, a dithered auditorium floor with wooden seat blocks at the exact
  D1 seat anchors, aisle runners, and a lobby band. Placeholder art —
  simple rectangles and dithering, replaced later by an Aseprite painting
  with zero code change since the seat anchors here are the D1 contract.

  Invoked by `priv/scripts/gen_placeholder_scene.exs`; lives in `lib/` (not
  inline in the script) so `palette/0` is available to `LobbyTui.SceneTest`
  without re-running the paint as a side effect of loading the test.
  """

  alias LobbyTui.World

  @width 176
  @height 192

  # Stage band: cell rows 2..13 -> px rows 4..27 (2 px per cell row).
  @stage_top 4
  @stage_bottom 27
  @apron_rows (@stage_bottom - 3)..@stage_bottom

  # Lobby/milling band: cell rows 84..92 -> px rows 168..185.
  @lobby_top 168
  @lobby_bottom 185
  @lobby_dither_rows @lobby_top..(@lobby_top + 3)

  # Wall trim: a top band plus both side margins, each 4 px wide/tall.
  @trim_rows 0..3
  @trim_cols_left 0..3
  @trim_cols_right (@width - 4)..(@width - 1)

  # Aisle runners: the center aisle plus a strip just inside each side margin.
  @aisle_center 84..87
  @aisle_left 4..7
  @aisle_right (@width - 8)..(@width - 5)

  # Seat rectangle: 12 px wide, 10 px tall (8 px back + 2 px base), the base
  # bottom-aligned to the seat anchor's own 2-px row band.
  @seat_width 12
  @seat_back_height 8
  @seat_base_height 2

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

    canvas =
      for y <- 0..(@height - 1) do
        for x <- 0..(@width - 1) do
          {r, g, b} = color_at(x, y, seat_pixels)
          ExPng.Color.rgb(r, g, b)
        end
      end

    File.mkdir_p!(Path.dirname(dest))
    image = ExPng.Image.new(canvas)
    {:ok, ^dest} = ExPng.Image.to_file(image, dest)
    IO.puts("wrote #{dest}")
    dest
  end

  defp color_at(x, y, seat_pixels) do
    cond do
      trim?(x, y) -> @slate
      y in @stage_top..@stage_bottom -> stage_color(x, y)
      y in @lobby_top..@lobby_bottom -> lobby_color(x, y)
      Map.has_key?(seat_pixels, {x, y}) -> Map.fetch!(seat_pixels, {x, y})
      aisle?(x) -> @aisle_red
      true -> floor_color(x, y)
    end
  end

  defp trim?(x, y), do: y in @trim_rows or x in @trim_cols_left or x in @trim_cols_right

  defp stage_color(_x, y) when y in @apron_rows, do: @apron_color

  defp stage_color(x, _y) do
    if rem(div(x, 4), 2) == 0, do: @curtain_a, else: @curtain_b
  end

  defp lobby_color(x, y) when y in @lobby_dither_rows do
    if rem(div(x, 2) + div(y, 2), 2) == 0, do: @lobby_dither, else: @lobby_floor
  end

  defp lobby_color(_x, _y), do: @lobby_floor

  defp aisle?(x), do: x in @aisle_center or x in @aisle_left or x in @aisle_right

  defp floor_color(x, y) do
    if rem(div(x, 2) + div(y, 2), 2) == 0, do: @floor_a, else: @floor_b
  end

  defp seat_pixel_map do
    World.seats()
    |> Enum.flat_map(&seat_pixels/1)
    |> Map.new()
  end

  # Seat anchor {x, y} (cell coords) -> px center (x, y * 2). The rectangle
  # is centered on column x and its 2-px base sits exactly on the anchor
  # row's own px band; the 8-px back rises above it.
  defp seat_pixels(%{x: x, y: y}) do
    left = x - div(@seat_width, 2)
    right = left + @seat_width - 1
    base_bottom = y * 2 + 1
    base_top = base_bottom - @seat_base_height + 1
    back_bottom = base_top - 1
    back_top = back_bottom - @seat_back_height + 1

    base = for(py <- base_top..base_bottom, px <- left..right, do: {{px, py}, @seat_base})
    back = for(py <- back_top..back_bottom, px <- left..right, do: {{px, py}, @seat_back})
    base ++ back
  end
end
