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
    - phones out, url + qr on screen, or ssh from your laptops
    - lobby_tui: the theatre from the interstitial, for real. a small pixel-art room, seats in front, a stage behind curtains
    - what everybody is about to do: pick a nick and an avatar, walk in with the arrows, grab a seat. seated -> post, it lands on the stage feed, everyone sees it
    - all in memory: ash on ets, presence for who is where, pubsub for the feed. leave -> gone, restart -> wiped. no personal info please

    - browser tab: lobby-tui.fly.dev (already open). pick avatar, walk, grab a seat near the stage
    - enough people seated -> open the curtains, stage feed shows what the seated crowd posts
    - terminal tab: hit enter on the typed `ssh <nick>@lobby-tui.fly.dev`, same room. the nick is `ssh_user` in mount, per-connection identity from the transport
    - browser tab: the livebook, already attached and evaluated, same room from a cell

    - one app module, EVERYWHERE
    - leave it running, glance at it before thanks
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
