defmodule TuisEverywhere.Slides.Thanks do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias TuisEverywhere.Slides.Ui

  @qr "feedback.png"

  def notes do
    """
    - thanks for staying
    - links: the library, and everything shown today on the second one
    - qr on the right: feedback for the talk, takes a minute
    - questions, feedback, contributions, showcases more than welcome: now, or find me
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

  def mount(_opts), do: {:ok, %{qr: Ui.load_image(@qr)}}

  # The feedback QR sits beside the links as a companion, not the main
  # act: a few rows taller than the text block, at any grid size. It
  # stays up through the questions, so the room has time to scan it.
  def render(%{qr: qr}, area) do
    Ui.headline_with_figure(area, banner(), {:lines, lines()}, captioned(Ui.figure(qr, @qr)),
      share: 35,
      max_rows: 11,
      banner: :bookend
    )
  end

  # Bookend to the title slide: that one paints itself violet letter
  # by letter; this one is already fully painted, no animation.
  defp banner, do: Line.new([Span.new("Thanks!", style: Ui.violet_style())])

  # "Questions?" over the links in the deck's cyan: full strength rather
  # than dim, since this is the slide people photograph and a projector
  # washes dim text out.
  defp lines do
    [Line.new([Span.new("Questions?", style: %Style{modifiers: [:bold]})]), Line.new([])] ++
      Enum.map(["" | @links], &Line.new([Span.new(&1, style: Ui.cyan_style())]))
  end

  # The figure gives up its bottom row to a muted "Feedback!" label, so
  # the QR keeps its aspect and the label sits right under the frame.
  defp captioned({kind, cols, rows, draw}) do
    {kind, cols, rows,
     fn %Rect{} = rect ->
       figure = %{rect | height: max(rect.height - 1, 0)}
       caption = %{rect | y: rect.y + figure.height, height: 1}
       label = %Paragraph{text: "Feedback!", alignment: :center, style: Ui.subtle_style()}
       draw.(figure) ++ [{label, caption}]
     end}
  end
end
