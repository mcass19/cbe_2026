defmodule TuisEverywhere.Slides.Ui do
  @moduledoc """
  Shared look for the TUIs-everywhere deck: one headline style, one
  bullet style, and one shape for the demo interstitials.

  Lives next to the slides but implements no `SlidesTui.Slide`
  behaviour, so deck discovery skips it — same pattern as any helper
  module sitting inside `lib/slides/`.

  The palette follows the talk identity used across the whole demo
  suite: Code BEAM magenta for the chrome (see `SlidesTui.Chrome`) and
  cyan for the small affordances, matching lobby_tui's CSS variables.
  """

  alias ExRatatui.{BigText, Layout, Style}
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout

  # lobby_tui's --tui-accent-2 (#22cede) — affordances and markers.
  @cyan {:rgb, 34, 206, 222}

  @headline_height 4
  @gap 2

  @doc "The quadrant-size BigText banner every headline uses."
  def headline(text) when is_binary(text) do
    BigText.new(text, pixel_size: :quadrant, alignment: :center)
  end

  @doc """
  A whole content slide in one call: BigText headline on top, a gap,
  then a left-aligned bullet column centered in the remaining space.
  Returns the `{widget, rect}` list `render/2` expects.
  """
  def headline_with_bullets(area, text, items) when is_list(items) do
    lines = bullet_lines(items)
    width = 2 + (items |> Enum.map(&String.length/1) |> Enum.max())

    bundle = SlidesLayout.center(area, height: @headline_height + @gap + length(lines))

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [
        {:length, @headline_height},
        {:length, @gap},
        {:min, 0}
      ])

    [
      {headline(text), head},
      {%Paragraph{text: lines}, SlidesLayout.center(body, width: width)}
    ]
  end

  @doc """
  The demo interstitial: a big `Demo` banner with a centered caption
  underneath. The caption is one string per line.
  """
  def demo(area, caption_lines) when is_list(caption_lines) do
    bundle =
      SlidesLayout.center(area, height: @headline_height + @gap + length(caption_lines))

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [
        {:length, @headline_height},
        {:length, @gap},
        {:min, 0}
      ])

    caption = %Paragraph{
      text: Enum.join(caption_lines, "\n"),
      alignment: :center,
      style: %Style{fg: @cyan}
    }

    [{headline("Demo"), head}, {caption, body}]
  end

  @doc "Bullet items as `Line`s — cyan marker, blank line between items."
  def bullet_lines(items) do
    items
    |> Enum.map(fn item ->
      Line.new([
        Span.new("▪ ", style: %Style{fg: @cyan, modifiers: [:bold]}),
        Span.new(item)
      ])
    end)
    |> Enum.intersperse(Line.new([]))
  end
end
