defmodule TuisEverywhere.Slides.Title do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.{Style, Subscription}
  alias ExRatatui.Text.{Line, Span}
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
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
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
    # Who first, where second: the name stays up while the room settles,
    # the handle in the deck's cyan like every other name to look up.
    subtitle = [
      Line.new([
        Span.new("Mauricio Cassola", style: %Style{modifiers: [:bold]}),
        Span.new(" · "),
        Span.new("mcass19", style: Ui.cyan_style())
      ]),
      Line.new([]),
      Line.new([
        Span.new("Code BEAM Europe 2026 · Haarlem, the Netherlands", style: Ui.subtle_style())
      ])
    ]

    Ui.headline_with_text(area, painted_title(min(tick, @letters)), {:lines, subtitle},
      alignment: :center,
      banner: :own
    )
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
