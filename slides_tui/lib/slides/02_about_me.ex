defmodule TuisEverywhere.Slides.AboutMe do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Style
  alias ExRatatui.Text.{Line, Span}
  alias TuisEverywhere.Slides.Ui

  @name_style %Style{modifiers: [:bold]}

  def title, do: "About me"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def mount(_opts), do: {:ok, %{image: Ui.load_image("profile.png")}}

  # No headline: the chrome's title says it. The photo grows with the
  # grid but stops at 60% of the height, so it doesn't loom over the room.
  def render(%{image: image}, area) do
    Ui.headline_with_figure(area, nil, {:lines, lines()}, Ui.figure(image, "profile.png"),
      share: 35,
      figure_side: :left,
      max_height: 60
    )
  end

  # Shell prompts share the title's violet rather than a terminal green,
  # so the deck's second hue carries through instead of a third colour.
  defp prompt_style, do: %{Ui.violet_style() | modifiers: [:bold]}

  defp lines do
    prompt = prompt_style()

    [
      Line.new([Span.new("$ whoami", style: prompt)]),
      Line.new([]),
      Line.new([Span.new("Mauricio Cassola", style: @name_style)]),
      Line.new([Span.new("Software Engineer")]),
      Line.new([]),
      Line.new([Span.new("$ cat links.txt", style: prompt)]),
      Line.new([]),
      Line.new([Span.new("mcass19.dev")]),
      Line.new([Span.new("mauricass19@gmail.com")]),
      Line.new([Span.new("github.com/mcass19")]),
      Line.new([Span.new("linkedin.com/in/mauricio-cassola")])
    ]
  end
end
