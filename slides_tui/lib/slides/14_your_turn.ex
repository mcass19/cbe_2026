defmodule TuisEverywhere.Slides.YourTurn do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Subscription
  alias ExRatatui.Widgets.Canvas
  alias ExRatatui.Widgets.Canvas.{Line, Points}
  alias TuisEverywhere.Slides.{Rocket, Ui}

  # The call to action, as a drawing: a row of launch ramps at night,
  # each with a rocket (see `Rocket`) and a rat riding it. The rats take
  # off one after another along the same diagonal as the BEAM
  # superpowers rocket, until only the last rocket is left, its seat
  # empty but for a blinking terminal cursor. That seat is the room's.
  # Then every rocket is back on its ramp and it goes again.

  @tick_ms 100
  # all on their ramps for a beat, then a launch every @stagger ticks;
  # each rocket fires its engine for @ignite ticks before it moves
  @hold_ticks 10
  @stagger 15
  @ignite 4
  @launched 3
  # long enough to clear the canvas from any ramp
  @flight_ticks 30
  # ~10s: the launches, then the empty seat on its own for a while
  @cycle 100
  @blink_ticks 5

  @x_max 200.0
  @y_max 100.0
  @canvas_width 120
  @canvas_height 22

  @scale 2.2
  @rat_scale 1.6
  @ground 6.0
  # Rocket centres, one per ramp; the last one stays.
  @pads [30.0, 76.0, 122.0, 168.0]
  @pad_y 30.0

  # The cursor in the empty seat, in rider units (see `Rocket.seated/3`):
  # a tall block sitting just clear of the hull, about the rat's size.
  @cursor_x {-0.2, 2.2}
  @cursor_y {2.4, 8.4}

  @stars [
    {14, 92},
    {37, 74},
    {52, 96},
    {71, 62},
    {93, 86},
    {109, 70},
    {128, 94},
    {146, 66},
    {163, 88},
    {181, 72},
    {194, 95},
    {24, 60}
  ]

  def notes do
    """
    - so: the beam deserves more tuis
    - come build one, and show me

    ---

    MORE
    - two runtimes: callbacks or reducer + a state machines guide
    - 25+ widgets: charts, canvas (the rockets), big text + code blocks (this deck)
    - chat kit: markdown, textarea, slash commands, throbber. build your own agent tui
    - custom widgets in pure elixir, no rust
    - images + 3D in the terminal: kitty, sixel, iterm2
    - mouse, focus ring, paste + clipboard, themes
    - testing: headless backend, test_mode + inject_event
    - debugging: runtime snapshots + traces
    - telemetry + performance guide, warns when an app falls behind
    - burrito: one binary, `mix ex_ratatui.gen.burrito`
    - usage-rules.md for agents, examples catalog, guides

    FUTURE
    - atomvm: tuis on microcontrollers
    - dsl
    """
  end

  @doc "How many ticks one full launch sequence takes before it starts over."
  def cycle_ticks, do: @cycle

  @doc "The tick at which the last rat has left the canvas."
  def all_gone_tick, do: launch_tick(@launched - 1) + @flight_ticks

  def mount(_opts), do: {:ok, %{tick: 0}}

  def subscriptions(_state), do: [Subscription.interval(:launchpad, @tick_ms, :tick)]

  def handle_info(:tick, %{tick: tick} = state),
    do: {:noreply, %{state | tick: rem(tick + 1, @cycle)}}

  def handle_info(_msg, state), do: {:noreply, state}

  def render(%{tick: tick}, area) do
    # Theme colours at render time; the canvas background too (see the
    # BEAM superpowers rocket).
    theme = Ui.theme()

    canvas = %Canvas{
      x_bounds: {0.0, @x_max},
      y_bounds: {0.0, @y_max},
      marker: :braille,
      background_color: theme.ground,
      shapes:
        [%Points{coords: stars(), color: theme.muted} | ground(theme.muted)] ++
          Enum.flat_map(@pads, &ramp(&1, theme.muted)) ++
          rockets(tick, theme) ++ cursor(tick, theme.text)
    }

    Ui.headline_with_figure(
      area,
      "Your turn!",
      nil,
      {:fit, @canvas_width, @canvas_height, &[{canvas, &1}]}
    )
  end

  defp stars, do: Enum.map(@stars, fn {x, y} -> {x * 1.0, y * 1.0} end)

  defp ground(color), do: [%Line{x1: 0.0, y1: @ground, x2: @x_max, y2: @ground, color: color}]

  defp launch_tick(i), do: @hold_ticks + @ignite + i * @stagger

  defp rockets(tick, theme) do
    {launched, [last]} = Enum.split(@pads, @launched)

    flying =
      launched
      |> Enum.with_index()
      |> Enum.flat_map(fn {x, i} -> launching(x, tick - launch_tick(i), tick, theme) end)

    flying ++ Rocket.shapes({last, @pad_y}, theme, scale: @scale)
  end

  # `t` counts ticks since lift-off: on the ramp before it, engine lit
  # for the last @ignite of those, then accelerating up the diagonal
  # until it's off the canvas.
  defp launching(x, t, tick, theme) do
    flame = if rem(tick, 2) == 0, do: 5, else: 8
    opts = [scale: @scale, rat: @rat_scale]

    cond do
      t < -@ignite -> Rocket.shapes({x, @pad_y}, theme, opts)
      t < 0 -> Rocket.shapes({x, @pad_y}, theme, [flame: flame] ++ opts)
      t < @flight_ticks -> Rocket.shapes(climb(x, t), theme, [flame: flame] ++ opts)
      true -> []
    end
  end

  defp climb(x, t) do
    d = 0.18 * t * t
    {x + d, @pad_y + d}
  end

  # A launch ramp under a rocket centred at `x`: a right triangle whose
  # slope runs just under the rocket's belly (the bottom fin hangs past it)
  # down to the ground.
  defp ramp(x, color) do
    {tx, ty} = Rocket.transform({5, -2.3}, x, @pad_y, @scale)
    {rx, ry} = Rocket.transform({-9, -2.3}, x, @pad_y, @scale)
    foot = rx - (ry - @ground)

    [{foot, @ground}, {tx, ty}, {tx, @ground}]
    |> Enum.chunk_every(2, 1, [{foot, @ground}])
    |> Enum.map(fn [{x1, y1}, {x2, y2}] ->
      %Line{x1: x1, y1: y1, x2: x2, y2: y2, color: color}
    end)
  end

  # A filled block in the last rocket's seat, on for @blink_ticks and
  # off for as long, like a terminal waiting for input.
  defp cursor(tick, color) do
    if rem(div(tick, @blink_ticks), 2) == 0 do
      place = Rocket.seated({List.last(@pads), @pad_y}, @scale, @rat_scale)
      {x0, x1} = @cursor_x
      {y0, y1} = @cursor_y

      for i <- 0..8 do
        x = x0 + (x1 - x0) * i / 8
        {ax, ay} = place.({x, y0})
        {bx, by} = place.({x, y1})
        %Line{x1: ax, y1: ay, x2: bx, y2: by, color: color}
      end
    else
      []
    end
  end
end
