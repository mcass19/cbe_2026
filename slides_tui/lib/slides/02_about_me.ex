defmodule TuisEverywhere.Slides.AboutMe do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Image, as: ImageWidget
  alias ExRatatui.{Layout, Style}
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  @photo_width 28
  @photo_height 14
  @gap 3
  @text_width 40

  @name_style %Style{modifiers: [:bold]}

  def title, do: "About me"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def mount(_opts) do
    bytes =
      :slides_tui
      |> :code.priv_dir()
      |> Path.join("slides/profile.png")
      |> File.read!()

    {:ok, image} = ImageWidget.new(bytes, resize: :fit)
    {:ok, %{image: image}}
  end

  def render(%{image: image}, area) do
    text_lines = lines()
    bundle_height = max(@photo_height, length(text_lines))

    bundle =
      SlidesLayout.center(area,
        width: @photo_width + @gap + @text_width,
        height: bundle_height
      )

    [photo_col, _gap, text_col] =
      Layout.split(bundle, :horizontal, [{:length, @photo_width}, {:length, @gap}, {:min, 0}])

    [
      {image, SlidesLayout.center(photo_col, height: @photo_height)},
      {%Paragraph{text: text_lines}, SlidesLayout.center(text_col, height: length(text_lines))}
    ]
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
