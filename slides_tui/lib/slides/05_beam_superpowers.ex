defmodule TuisEverywhere.Slides.BeamSuperpowers do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Subscription
  alias ExRatatui.Widgets.Canvas
  alias ExRatatui.Widgets.Canvas.Points
  alias TuisEverywhere.Slides.{Rocket, Ui}

  # Section divider: the headline plus a small rocket (see `Rocket`),
  # the ratatui rat riding it, climbing across a starfield on a Canvas.
  # One animated thing, on screen for the one sentence that opens the
  # BEAM half of the talk; the interval is torn down the moment we leave
  # the slide. The closing slide launches the same rockets.

  @tick_ms 100
  # ~6s from bottom-left to top-right, then it re-enters and goes again
  @flight_ticks 60

  # Canvas coordinate space. Braille cells are 2×4 pixels, so a 2:1
  # x:y range keeps shapes undistorted on a roughly 2:1 cell grid.
  @x_max 200.0
  @y_max 100.0
  @canvas_width 120
  @canvas_height 22

  @scale 3.0
  @rat_scale 2.2

  # How far off-canvas the flight starts and ends, so the whole rocket
  # (flame to rat) is out of sight at both ends.
  @margin 25.0

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

  def notes do
    """
    - with that: a liveview-like callback runtime, local terminal, all my first ideas done
    - now the fun part, what makes this more than a local toy
    - processes, supervision, distribution, now with a tui screen
    - CHECKPOINT ~6:30
    """
  end

  @doc "How many ticks one crossing takes before the rocket re-enters."
  def flight_ticks, do: @flight_ticks

  def mount(_opts), do: {:ok, %{tick: 0}}

  def subscriptions(_state), do: [Subscription.interval(:rocket, @tick_ms, :fly)]

  def handle_info(:fly, %{tick: tick} = state),
    do: {:noreply, %{state | tick: rem(tick + 1, @flight_ticks)}}

  def handle_info(_msg, state), do: {:noreply, state}

  # The sky keeps its @canvas_width:@canvas_height shape at any size,
  # so the rocket never stretches.
  def render(%{tick: tick}, area) do
    # Colours come from the active theme at render time. The canvas
    # washes its own background, so it gets the theme's ground too;
    # left unset it would paint the terminal's background as a box.
    theme = Ui.theme()

    canvas = %Canvas{
      x_bounds: {0.0, @x_max},
      y_bounds: {0.0, @y_max},
      marker: :braille,
      background_color: theme.ground,
      shapes: [%Points{coords: stars(), color: theme.muted} | rocket(tick, theme)]
    }

    Ui.headline_with_figure(
      area,
      "BEAM superpowers",
      nil,
      {:fit, @canvas_width, @canvas_height, &[{canvas, &1}]}
    )
  end

  defp stars, do: Enum.map(@stars, fn {x, y} -> {x * 1.0, y * 1.0} end)

  # The rocket's position along its diagonal for a given tick, with a
  # margin so it enters and leaves fully off-canvas.
  defp position(tick) do
    t = tick / @flight_ticks
    {-@margin + (@x_max + 2 * @margin + 10.0) * t, -@margin + (@y_max + 2 * @margin + 10.0) * t}
  end

  # Two-frame flicker: the exhaust alternates between a short and a
  # long plume every tick.
  defp rocket(tick, theme) do
    flame = if rem(tick, 2) == 0, do: 5, else: 8
    Rocket.shapes(position(tick), theme, scale: @scale, flame: flame, rat: @rat_scale)
  end
end
