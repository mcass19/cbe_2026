defmodule TuisEverywhere.Slides.Title do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.{Layout, Style, Subscription}
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  @title "TUIs everywhere"

  # The headline paints itself one letter at a time in violet, holds
  # the finished word for a beat, then snaps back and starts over. Slow
  # enough to read as deliberate while the room settles; the interval
  # is torn down the moment we leave the slide.
  @tick_ms 200
  @hold_ticks 7

  @letters @title |> String.graphemes() |> Enum.reject(&(&1 == " ")) |> length()
  @cycle @letters + @hold_ticks

  def notes do
    """
    - hi everyone, thanks for having me
    - tuis: terminal user interfaces. a library to build them in elixir
    - ratatui + beam superpowers
    - there's a demo, first talk, of course
    """
  end

  @doc "How many ticks the fully painted title stays on screen before resetting."
  def hold_ticks, do: @hold_ticks

  def mount(_opts), do: {:ok, %{tick: 0}}

  def subscriptions(_state), do: [Subscription.interval(:title_paint, @tick_ms, :paint)]

  def handle_info(:paint, %{tick: tick} = state),
    do: {:noreply, %{state | tick: rem(tick + 1, @cycle + 1)}}

  def handle_info(_msg, state), do: {:noreply, state}

  def render(%{tick: tick}, area) do
    bundle = SlidesLayout.center(area, height: 9)

    [banner, _gap, sub] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    subtitle = %Paragraph{
      text: "Code BEAM Europe 2026 - Haarlem, the Netherlands",
      alignment: :center,
      style: %Style{modifiers: [:dim]}
    }

    [{Ui.headline(painted_title(min(tick, @letters))), banner}, {subtitle, sub}]
  end

  # One span per character so BigText can colour letters independently;
  # the first `count` non-space letters carry the violet, the rest stay
  # in the headline's default colour. Spaces never count as painted.
  defp painted_title(count) do
    {spans, _} =
      @title
      |> String.graphemes()
      |> Enum.map_reduce(0, fn
        " ", seen -> {Span.new(" "), seen}
        char, seen when seen < count -> {Span.new(char, style: Ui.violet_style()), seen + 1}
        char, seen -> {Span.new(char), seen + 1}
      end)

    Line.new(spans)
  end
end
