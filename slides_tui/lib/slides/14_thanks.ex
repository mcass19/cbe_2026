defmodule TuisEverywhere.Slides.Thanks do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Style
  alias ExRatatui.Text.{Line, Span}
  alias TuisEverywhere.Slides.Ui

  def notes do
    """
    - thanks for staying
    - links: the library, and everything shown today on the second one
    - questions: now, or find me
    - feedback, contributions, showcases more than welcome
    - and remember, TUIs are (or can be) everywhere
    - thank you all
    """
  end

  # Library links first, then a blank line, then the talk repo — schemes
  # dropped to match the about-me slide.
  @links [
    "hex.pm/packages/ex_ratatui",
    "ex-ratatui.hexdocs.pm",
    "",
    "github.com/mcass19/cbe_2026"
  ]

  def render(_state, area) do
    # "Questions?" under the banner, then the links in the deck's cyan:
    # full strength rather than dim, since this is the slide people
    # photograph and a projector washes dim text out.
    lines =
      [Line.new([Span.new("Questions?", style: %Style{modifiers: [:bold]})]), Line.new([])] ++
        Enum.map(["" | @links], &Line.new([Span.new(&1, style: Ui.cyan_style())]))

    # Bookend to the title slide: that one paints itself violet letter
    # by letter; this one is already fully painted, no animation.
    banner = Line.new([Span.new("Thanks!", style: Ui.violet_style())])
    Ui.headline_with_text(area, banner, {:lines, lines}, alignment: :center, banner: :own)
  end
end
