defmodule TuisEverywhere.Slides.AboutMe do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Image, as: ImageWidget
  alias ExRatatui.{Layout, Style}
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout

  @photo_width 28
  @photo_height 14
  @gap 3
  @text_width 40

  @prompt_style %Style{fg: :green, modifiers: [:bold]}
  @name_style %Style{modifiers: [:bold]}

  def title, do: "About me"

  def notes do
    """
    ## whoami

    - Mauricio "Mauri" Cassola — software engineer from Uruguay
    - day job: Elixir + a lot of OTP plumbing
    - author of ex_ratatui — the rest of this deck is what fell out of that
    - keep it short, the toys are the talk

    Site: mcass19.dev
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

  defp lines do
    [
      Line.new([Span.new("$ whoami", style: @prompt_style)]),
      Line.new([]),
      Line.new([Span.new("Mauri", style: @name_style)]),
      Line.new([Span.new("Software Engineer from Uruguay")]),
      Line.new([]),
      Line.new([Span.new("$ cat links.txt", style: @prompt_style)]),
      Line.new([]),
      Line.new([Span.new("mauricass19@gmail.com")]),
      Line.new([Span.new("github.com/mcass19")]),
      Line.new([Span.new("linkedin.com/in/mauricio-cassola")])
    ]
  end
end
