defmodule TuisEverywhere.Slides.Kino do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  @screenshot "kino.png"

  @bullets [
    "a TUI inside a Livebook cell — `Kino.JS.Live` + xterm.js",
    "a custom transport, for real: ANSI bytes out, keys and resizes back",
    "any `ExRatatui.App` runs unchanged, `Mix.install` and go",
    "inline images over Sixel, themes, one-shot frames for docs",
    "attached runtime: a notebook cell driving a TUI on a running node",
    {:links, ["hex.pm/packages/kino_ex_ratatui", "kino-ex-ratatui.hexdocs.pm"]}
  ]

  def title, do: "kino_ex_ratatui"

  def notes do
    """
    - a custom transport for real: kino_ex_ratatui. first way out of the terminal
    - Kino.JS.Live + xterm.js. ansi bytes to the browser, keys + resizes back
    - one module on ExRatatui.Transport.ByteStream, that's the whole transport
    - terminal still there in spirit, lives in a notebook cell. app has no idea
    - images over sixel (xterm image addon), themes, frame/2 for docs
    - Mix.install, done
    - livebook attaches to running nodes -> a notebook cell is one more door. we use it in the demo
    """
  end

  def mount(_opts), do: {:ok, %{screenshot: Ui.load_image(@screenshot)}}

  def render(%{screenshot: screenshot}, area) do
    Ui.headline_with_bullets_and_figure(area, "Livebook", @bullets, screenshot, @screenshot)
  end
end
