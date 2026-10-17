defmodule TuisEverywhere.Slides.Demo do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Subscription
  alias ExRatatui.Widgets.Canvas
  alias ExRatatui.Widgets.Canvas.Line
  alias TuisEverywhere.Slides.{Rat, Ui}

  # Demo interstitial: a small theatre on a Canvas — the lobby_tui room
  # in miniature. The curtains open when the slide comes up and reveal
  # a name badge swinging centre stage; rows of seats sit in front.
  # After a few swings the curtains close again, pause, and reopen, for
  # as long as the slide is up. The badge is the first thing shown in
  # the demo, the theatre is where everybody ends up. Same subscription
  # pattern as the rocket; torn down the moment we leave the slide.

  @tick_ms 100
  # one full badge swing, left to right and back, in ~4s
  @swing_ticks 40
  @swing_amplitude 0.11
  # one curtain cycle: ~3s opening, three swings on stage, ~3s closing,
  # ~2s closed. The total is a multiple of @swing_ticks so the badge's
  # phase lines up with the curtains on every pass.
  @open_ticks 30
  @hold_ticks 3 * @swing_ticks
  @close_ticks 30
  @closed_ticks 20
  @cycle @open_ticks + @hold_ticks + @close_ticks + @closed_ticks

  @x_max 200.0
  @y_max 100.0
  @canvas_width 120
  @canvas_height 22

  # Stage: a proscenium frame across the top two thirds of the canvas.
  @stage_left 30.0
  @stage_right 170.0
  @stage_bottom 36.0
  @stage_top 96.0
  @folds 5

  # Seats: three rows of small "U"s in front of the stage.
  @seat_rows [26.0, 16.0, 6.0]
  @seat_columns [50.0, 66.0, 82.0, 98.0, 114.0, 130.0, 146.0]

  # Badge on a lanyard, relative to its pivot on the stage's top edge.
  @pivot {100.0, @stage_top}
  @strap_left [{0, 0}, {-8, -20}]
  @strap_right [{0, 0}, {8, -20}]
  @badge [{-16, -20}, {16, -20}, {16, -50}, {-16, -50}, {-16, -20}]
  @clip [{-3, -20}, {-3, -24}, {3, -24}, {3, -20}]
  # The badge's "photo": the ratatui rat (see `Rat`) sitting on the name
  # line and waving, shifted right so body and tail sit centred on the card.
  @name [{-12, -45}, {12, -45}]
  @rat_origin {3.5, -45}
  @rat_scale 1.6

  def notes do
    """
    - badge: credit Lars Wikman for Goatmire, Gus Workman for the badge. nerves, 400x300 e-ink, two buttons
    - just show it. images are dithered to black and white
    - fairphone 3: credit Marc Lainez, nerves everywhere. nerves discord for the fun stuff
    - same app as the pi on the previous slide: three devices, one app
    """
  end

  def mount(_opts), do: {:ok, %{tick: 0}}

  def subscriptions(_state), do: [Subscription.interval(:theatre, @tick_ms, :tick)]

  def handle_info(:tick, %{tick: tick} = state),
    do: {:noreply, %{state | tick: rem(tick + 1, @cycle)}}

  def handle_info(_msg, state), do: {:noreply, state}

  # The theatre keeps its @canvas_width:@canvas_height shape at any
  # size, so the seats and curtains never stretch.
  def render(%{tick: tick}, area) do
    # Theme colours at render time; the canvas background too, or it
    # paints the terminal's own background as a box (see the rocket).
    theme = Ui.theme()

    canvas = %Canvas{
      x_bounds: {0.0, @x_max},
      y_bounds: {0.0, @y_max},
      marker: :braille,
      background_color: theme.ground,
      shapes:
        frame(theme.violet) ++
          seats(theme.violet) ++ curtains(tick, theme.accent) ++ badge(tick, theme)
    }

    Ui.headline_with_figure(
      area,
      "Demo!",
      nil,
      {:fit, @canvas_width, @canvas_height, &[{canvas, &1}]}
    )
  end

  @doc """
  How far the curtains are open for a tick, from 0.0 (closed) to 1.0.
  Follows the cycle: opening, held open, closing, held closed, repeat.
  """
  def open_fraction(tick) do
    t = rem(tick, @cycle)

    cond do
      t < @open_ticks ->
        t / @open_ticks

      t < @open_ticks + @hold_ticks ->
        1.0

      t < @open_ticks + @hold_ticks + @close_ticks ->
        (@open_ticks + @hold_ticks + @close_ticks - t) / @close_ticks

      true ->
        0.0
    end
  end

  @doc "How many ticks one full curtain cycle takes."
  def cycle_ticks, do: @cycle

  @doc "The badge's swing angle (radians) for a tick — a full sine period per swing."
  def angle(tick), do: @swing_amplitude * :math.sin(2 * :math.pi() * tick / @swing_ticks)

  defp frame(color) do
    polyline(
      [
        {@stage_left, @stage_bottom},
        {@stage_left, @stage_top},
        {@stage_right, @stage_top},
        {@stage_right, @stage_bottom},
        {@stage_left, @stage_bottom}
      ],
      & &1,
      color
    )
  end

  defp seats(color) do
    for y <- @seat_rows, x <- @seat_columns, reduce: [] do
      acc ->
        polyline([{x - 4, y + 5}, {x - 4, y}, {x + 4, y}, {x + 4, y + 5}], & &1, color) ++ acc
    end
  end

  # Two panels that part from the centre. Each panel keeps @folds
  # vertical lines spread across whatever width it still covers, so the
  # folds bunch up as the curtain gathers at the edge.
  defp curtains(tick, color) do
    open = open_fraction(tick)
    centre = (@stage_left + @stage_right) / 2
    half = (@stage_right - @stage_left) / 2
    # closed: both edges meet at the centre. open: each edge sits a
    # little way in from the frame, with the folds gathered behind it.
    edge_offset = (half - 6) * open

    left_edge = centre - edge_offset
    right_edge = centre + edge_offset
    top = @stage_top - 2
    bottom = @stage_bottom + 2

    folds(@stage_left + 1, left_edge, top, bottom, color) ++
      folds(right_edge, @stage_right - 1, top, bottom, color)
  end

  defp folds(from, to, top, bottom, color) do
    step = (to - from) / @folds

    for i <- 0..@folds do
      x = from + i * step
      %Line{x1: x, y1: top, x2: x, y2: bottom, color: color}
    end
  end

  # The badge only shows once the curtains have parted enough to clear it.
  defp badge(tick, theme) do
    if open_fraction(tick) < 0.5 do
      []
    else
      place = &transform(&1, angle(tick))

      {rx, ry} = @rat_origin
      on_card = fn {x, y} -> place.({rx + @rat_scale * x, ry + @rat_scale * y}) end

      Enum.flat_map([@strap_left, @strap_right], &polyline(&1, place, theme.accent)) ++
        Enum.flat_map([@badge, @clip, @name], &polyline(&1, place, theme.violet)) ++
        Rat.shapes(on_card, theme.text, :sitting)
    end
  end

  defp polyline(points, place, color) do
    points
    |> Enum.map(place)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{x1, y1}, {x2, y2}] ->
      %Line{x1: x1 * 1.0, y1: y1 * 1.0, x2: x2 * 1.0, y2: y2 * 1.0, color: color}
    end)
  end

  # Rotate around the pivot, then translate to it.
  defp transform({x, y}, angle) do
    {px, py} = @pivot
    c = :math.cos(angle)
    s = :math.sin(angle)
    {px + x * c - y * s, py + x * s + y * c}
  end
end
