defmodule TuisEverywhere.Slides.Phoenix do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  @screenshot "phoenix.png"

  @bullets [
    "*no terminal emulator*",
    "cell diffs over the socket",
    "a ~5KB JS hook",
    "3D + images as PNG",
    {:links, ["hex.pm/packages/phoenix_ex_ratatui", "phoenix-ex-ratatui.hexdocs.pm"]}
  ]

  def title, do: "phoenix_ex_ratatui"

  def notes do
    """
    - first thing wearing a cell session: phoenix_ex_ratatui. same relation as kino to the byte stream
    - no xterm, no ansi. cell diffs over the liveview socket, tiny hook paints spans. ~5KB js
    - two shapes: LiveView full page, LiveComponent inside a page. same module is the liveview and the app
    - handlers return navigate / patch / redirect intents
    - bandwidth: a static screen costs nothing, a ticking dashboard costs the cells that changed
    """
  end

  def mount(_opts), do: {:ok, %{screenshot: Ui.load_image(@screenshot)}}

  def render(%{screenshot: screenshot}, area) do
    Ui.headline_with_bullets_and_figure(area, "LiveView", @bullets, screenshot, @screenshot)
  end
end
