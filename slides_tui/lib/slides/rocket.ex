defmodule TuisEverywhere.Slides.Rocket do
  @moduledoc """
  The deck's rocket as Canvas shapes: the hull, an optional exhaust
  plume, and the rat (see `Rat`) riding on top. Always pointed up and to
  the right at 45°, the way it flies on the BEAM superpowers slide and
  leaves the launchpad on the closing one.

  Lives next to the slides but implements no `SlidesTui.Slide`
  behaviour, so deck discovery skips it (same as `Ui`).

  The outline is in rocket units, nose along +x, about 18 long (fins
  to nose) and 8 across; `scale` turns units into canvas coordinates.
  """

  alias ExRatatui.Widgets.Canvas.Line
  alias TuisEverywhere.Slides.Rat

  @body [{-6, 2}, {4, 2}, {4, -2}, {-6, -2}, {-6, 2}]
  @nose [{4, 2}, {9, 0}, {4, -2}]
  @fin_top [{-6, 2}, {-9, 4}, {-4, 2}]
  @fin_bottom [{-6, -2}, {-9, -4}, {-4, -2}]

  # Where the rider sits, on the hull's top edge behind the middle.
  @seat {-2, 2}

  @cos45 :math.cos(:math.pi() / 4)
  @sin45 :math.sin(:math.pi() / 4)

  @doc """
  The rocket centred at `{cx, cy}`, as Canvas shapes in `theme`'s
  colours.

  Options:

    * `:scale` — canvas coordinates per rocket unit (required)
    * `:flame` — plume length in rocket units, or `nil` (default) for
      none
    * `:rat` — the riding rat's scale, or `nil` (default) for an empty
      seat
  """
  def shapes({cx, cy}, theme, opts) do
    scale = Keyword.fetch!(opts, :scale)
    place = &transform(&1, cx, cy, scale)

    hull =
      Enum.flat_map([@body, @nose, @fin_top, @fin_bottom], &polyline(&1, place, theme.violet))

    flame =
      case Keyword.get(opts, :flame) do
        nil -> []
        len -> flame(len, place, theme.accent)
      end

    rat =
      case Keyword.get(opts, :rat) do
        nil -> []
        rat_scale -> Rat.shapes(seated({cx, cy}, scale, rat_scale), theme.text, :riding)
      end

    hull ++ rat ++ flame
  end

  @doc """
  Maps world-aligned rider units onto the canvas from the seat of a
  rocket at `{cx, cy}`: what `Rat` rides on, and what a slide can use
  to draw something else in the seat. The hull's top edge runs along
  y = x in these units.
  """
  def seated({cx, cy}, scale, rider_scale) do
    {sx, sy} = transform(@seat, cx, cy, scale)
    fn {x, y} -> {sx + rider_scale * x, sy + rider_scale * y} end
  end

  @doc """
  Maps a point in rocket units onto the canvas for a rocket at
  `{cx, cy}`: rotate 45° (nose to the upper right), scale, translate.
  """
  def transform({x, y}, cx, cy, scale) do
    {cx + scale * (x * @cos45 - y * @sin45), cy + scale * (x * @sin45 + y * @cos45)}
  end

  defp flame(len, place, color) do
    core = [{-6, 0}, {-6 - len, 0}]
    upper = [{-6, 1}, {-6 - len * 0.6, 1.5}]
    lower = [{-6, -1}, {-6 - len * 0.6, -1.5}]

    Enum.flat_map([core, upper, lower], &polyline(&1, place, color))
  end

  defp polyline(points, place, color) do
    points
    |> Enum.map(place)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{x1, y1}, {x2, y2}] ->
      %Line{x1: x1 * 1.0, y1: y1 * 1.0, x2: x2 * 1.0, y2: y2 * 1.0, color: color}
    end)
  end
end
