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
    - phones out, url + qr on screen, or ssh from your laptops
    - lobby_tui: the theatre from the interstitial, for real. a small pixel-art room, seats in front, a stage behind curtains
    - what everybody is about to do: pick a nick and an avatar, walk in with the arrows, grab a seat. seated -> post, it lands on the stage feed, everyone sees it
    - all in memory: ash on ets, presence for who is where, pubsub for the feed. leave -> gone, restart -> wiped. no personal info please
    - switching: "here's the browser" / "here's ssh" / "here's livebook"
    - CHECKPOINT ~17:00
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
