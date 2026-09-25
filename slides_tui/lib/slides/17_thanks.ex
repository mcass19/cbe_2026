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
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
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

    bundle = SlidesLayout.center(area, height: 4 + 2 + length(lines))

    [banner, _gap, sub] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    links = %Paragraph{text: lines, alignment: :center}

    # Bookend to the title slide: that one paints itself violet letter
    # by letter; this one is already fully painted, no animation.
    [
      {Ui.headline(Line.new([Span.new("Thanks!", style: Ui.violet_style())])), banner},
      {links, sub}
    ]
  end
end
