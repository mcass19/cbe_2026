defmodule TuisEverywhere.Slides.Lobby do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Text.{Line, Span}
  alias TuisEverywhere.Slides.Ui

  @qr "qr.png"
  @url "lobby-tui.fly.dev"

  # Shell-prompt style, like the about-me slide: the ways into the room.
  @ways [
    {"open", "https://#{@url}"},
    {"ssh", "<nick>@#{@url}"},
    {"livebook", "attached to the same node"}
  ]

  def title, do: "lobby_tui"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def mount(_opts), do: {:ok, %{qr: Ui.load_image(@qr)}}

  # The QR takes the bigger share: it has to scan from the back row.
  def render(%{qr: qr}, area) do
    Ui.headline_with_figure(area, "Everybody in", {:lines, lines()}, Ui.figure(qr, @qr),
      share: 55
    )
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
