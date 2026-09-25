defmodule TuisEverywhere.Slides.BeamSuperpowers do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.{Layout, Subscription}
  alias ExRatatui.Widgets.Canvas
  alias ExRatatui.Widgets.Canvas.{Line, Points}
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  # Section divider: the headline plus a small rocket climbing across a
  # starfield on a Canvas. One animated thing, on screen for the one
  # sentence that opens the BEAM half of the talk; the interval is torn
  # down the moment we leave the slide.

  @tick_ms 100
  # ~6s from bottom-left to top-right, then it re-enters and goes again
  @flight_ticks 60

  # Canvas coordinate space. Braille cells are 2×4 pixels, so a 2:1
  # x:y range keeps shapes undistorted on a roughly 2:1 cell grid.
  @x_max 200.0
  @y_max 100.0
  @canvas_width 120
  @canvas_height 22

  # Rocket outline in local coordinates, nose along +x. Rotated 45°
  # and translated at render time.
  @scale 2.4
  @body [{-6, 2}, {4, 2}, {4, -2}, {-6, -2}, {-6, 2}]
  @nose [{4, 2}, {9, 0}, {4, -2}]
  @fin_top [{-6, 2}, {-9, 4}, {-4, 2}]
  @fin_bottom [{-6, -2}, {-9, -4}, {-4, -2}]

  # A fixed sky so the stars don't twinkle away every frame.
  @stars [
    {12, 88},
    {31, 63},
    {47, 92},
    {58, 41},
    {73, 77},
    {90, 18},
    {104, 95},
    {117, 52},
    {133, 30},
    {148, 84},
    {161, 12},
    {176, 66},
    {189, 44},
    {24, 21},
    {66, 8},
    {121, 74},
    {154, 57},
    {183, 91},
    {38, 47},
    {97, 61}
  ]

  @violet Ui.violet()
  @magenta {:rgb, 225, 31, 193}

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  @doc "How many ticks one crossing takes before the rocket re-enters."
  def flight_ticks, do: @flight_ticks

  def mount(_opts), do: {:ok, %{tick: 0}}

  def subscriptions(_state), do: [Subscription.interval(:rocket, @tick_ms, :fly)]

  def handle_info(:fly, %{tick: tick} = state),
    do: {:noreply, %{state | tick: rem(tick + 1, @flight_ticks)}}

  def handle_info(_msg, state), do: {:noreply, state}

  def render(%{tick: tick}, area) do
    bundle = SlidesLayout.center(area, width: @canvas_width, height: 4 + 2 + @canvas_height)

    [head, _gap, sky] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    canvas = %Canvas{
      x_bounds: {0.0, @x_max},
      y_bounds: {0.0, @y_max},
      marker: :braille,
      shapes: [%Points{coords: stars(), color: :dark_gray} | rocket(tick)]
    }

    [{Ui.headline("BEAM superpowers"), head}, {canvas, sky}]
  end

  defp stars, do: Enum.map(@stars, fn {x, y} -> {x * 1.0, y * 1.0} end)

  # The rocket's position along its diagonal for a given tick, with a
  # margin so it enters and leaves fully off-canvas.
  defp position(tick) do
    t = tick / @flight_ticks
    {-20.0 + (@x_max + 40.0) * t, -15.0 + (@y_max + 30.0) * t}
  end

  defp rocket(tick) do
    {cx, cy} = position(tick)
    place = &transform(&1, cx, cy)

    hull =
      [@body, @nose, @fin_top, @fin_bottom]
      |> Enum.flat_map(&polyline(&1, place, @violet))

    hull ++ flame(tick, place)
  end

  # Two-frame flicker: the exhaust alternates between a short and a
  # long plume every tick.
  defp flame(tick, place) do
    len = if rem(tick, 2) == 0, do: 5, else: 8
    core = [{-6, 0}, {-6 - len, 0}]
    upper = [{-6, 1}, {-6 - len * 0.6, 1.5}]
    lower = [{-6, -1}, {-6 - len * 0.6, -1.5}]

    Enum.flat_map([core, upper, lower], &polyline(&1, place, @magenta))
  end

  defp polyline(points, place, color) do
    points
    |> Enum.map(place)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{x1, y1}, {x2, y2}] ->
      %Line{x1: x1, y1: y1, x2: x2, y2: y2, color: color}
    end)
  end

  # Rotate 45° (nose to the upper right), scale, translate.
  @cos45 :math.cos(:math.pi() / 4)
  @sin45 :math.sin(:math.pi() / 4)
  defp transform({x, y}, cx, cy) do
    {cx + @scale * (x * @cos45 - y * @sin45), cy + @scale * (x * @sin45 + y * @cos45)}
  end
end
