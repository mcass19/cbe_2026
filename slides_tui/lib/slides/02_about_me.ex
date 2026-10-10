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
    - mauricio "mauri" cassola, software engineer from uruguay
    - netherlands, almost 4 years
    - the picture i use everywhere, mcass19 handle for all the links
    - elixir for many years, from different angles - type system, day to day now
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
      Line.new([Span.new("@mcass19")]),
      Line.new([Span.new("mcass19.dev")]),
      Line.new([Span.new("hi@mcass19.dev")])
    ]
  end
end
