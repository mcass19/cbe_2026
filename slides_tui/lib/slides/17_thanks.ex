defmodule TuisEverywhere.Slides.Thanks do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.{Layout, Style}
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout
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
    bundle = SlidesLayout.center(area, height: 4 + 2 + length(@links))

    [banner, _gap, sub] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    links = %Paragraph{
      text: Enum.join(@links, "\n"),
      alignment: :center,
      style: %Style{modifiers: [:dim]}
    }

    # Bookend to the title slide: that one paints itself violet letter
    # by letter; this one is already fully painted, no animation.
    [
      {Ui.headline(Line.new([Span.new("Thanks!", style: Ui.violet_style())])), banner},
      {links, sub}
    ]
  end
end
