defmodule TuisEverywhere.Slides.Rat do
  @moduledoc """
  The deck's mascot: the ratatui rat as Canvas shapes, sitting up in
  side view, facing right, its tail trailing behind.

  Lives next to the slides but implements no `SlidesTui.Slide`
  behaviour, so deck discovery skips it (same as `Ui`).

  The outline is in rat units: the rat sits at the origin, about 13
  units wide (tail included) and 10 tall. `shapes/3` takes a `place`
  function that maps a rat-unit point onto the canvas, so each slide
  scales, moves and tilts the rat however its scene needs.

  Poses differ in what the rat sits on:

    * `:riding` — a slope rising along y = x (the rocket's hull), paw
      down holding on
    * `:sitting` — level ground at y = 0, paw up in a wave
  """

  alias ExRatatui.Widgets.Canvas.{Line, Points}

  # Back, head and chest, the same in every pose; each pose adds the
  # points where the rat meets its ground.
  @outline [
    {-2.5, 1},
    {-2.6, 3.5},
    {-1.5, 5.5},
    {0.2, 6.6},
    {0.9, 7.9},
    {4.4, 6.2},
    {1.7, 5.7},
    {2.0, 3.8}
  ]
  @ear [{0.1, 7.6}, {-1.2, 8.4}, {-1.3, 9.6}, {-0.4, 10.2}, {0.6, 9.8}, {1.0, 8.0}]
  @eye {1.9, 6.9}

  @poses %{
    riding: %{
      rear: {-1, -1},
      front: {1, 1},
      paw: [{1.9, 4.3}, {3.5, 3.5}],
      tail: [{-2.2, 0.2}, {-3.8, -0.6}, {-5.5, 0.4}, {-7.2, -0.6}, {-8.8, 0.2}]
    },
    sitting: %{
      rear: {-2.0, 0},
      front: {1.6, 0},
      paw: [{1.9, 4.3}, {3.6, 3.9}, {4.4, 4.8}],
      tail: [{-2.2, 0.3}, {-3.8, 0}, {-5.5, 0.9}, {-7.2, 0.1}, {-8.8, 0.8}]
    }
  }

  @doc """
  The rat in `pose` (`:riding` or `:sitting`): its lines and eye in
  `color`, each point mapped through `place` from rat units to canvas
  coordinates.
  """
  def shapes(place, color, pose) do
    %{rear: rear, front: front, paw: paw, tail: tail} = Map.fetch!(@poses, pose)
    body = [rear | @outline] ++ [front]

    lines =
      Enum.flat_map([body, @ear, paw, tail], fn points ->
        points
        |> Enum.map(place)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [{x1, y1}, {x2, y2}] ->
          %Line{x1: x1 * 1.0, y1: y1 * 1.0, x2: x2 * 1.0, y2: y2 * 1.0, color: color}
        end)
      end)

    {ex, ey} = place.(@eye)
    lines ++ [%Points{coords: [{ex * 1.0, ey * 1.0}], color: color}]
  end
end
