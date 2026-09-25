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
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def mount(_opts), do: {:ok, %{screenshot: Ui.load_image(@screenshot)}}

  def render(%{screenshot: screenshot}, area) do
    Ui.headline_with_bullets_and_figure(area, "Livebook", @bullets, screenshot, @screenshot)
  end
end
