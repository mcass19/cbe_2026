defmodule TuisEverywhere.Slides.Lobby do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Layout
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  @qr "qr.png"
  @url "lobby-tui.fly.dev"

  # Shell-prompt style, like the about-me slide: the ways into the room.
  @ways [
    {"open", "https://#{@url}"},
    {"ssh", "<nick>@#{@url}"},
    {"livebook", "attached to the same node"}
  ]

  # The QR is square: this many rows, twice as many columns. Big on
  # purpose, it has to scan from the back row.
  @figure_rows 30
  @gap 8

  def title, do: "lobby_tui"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def mount(_opts), do: {:ok, %{qr: Ui.load_image(@qr)}}

  def render(%{qr: qr}, area) do
    lines = lines()
    text_height = length(lines)

    text_width =
      @ways |> Enum.map(fn {cmd, arg} -> String.length("$ #{cmd} #{arg}") end) |> Enum.max()

    figure_width = 2 * @figure_rows
    body_height = max(text_height, @figure_rows)

    bundle =
      SlidesLayout.center(area,
        width: text_width + @gap + figure_width,
        height: 4 + 2 + body_height
      )

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    [text_col, _mid, figure_col] =
      Layout.split(body, :horizontal, [
        {:length, text_width},
        {:length, @gap},
        {:length, figure_width}
      ])

    [
      {Ui.headline("Everybody in"), head},
      {%Paragraph{text: lines}, SlidesLayout.center(text_col, height: text_height)}
      | Ui.figure(qr, @qr, SlidesLayout.center(figure_col, height: @figure_rows))
    ]
  end

  defp lines do
    prompt = %{Ui.violet_style() | modifiers: [:bold]}

    @ways
    |> Enum.map(fn {cmd, arg} ->
      Line.new([Span.new("$ #{cmd} ", style: prompt), Span.new(arg)])
    end)
    |> Enum.intersperse(Line.new([]))
  end
end
