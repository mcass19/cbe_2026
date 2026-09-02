defmodule TuisEverywhere.Slides.Phoenix do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  @screenshot "phoenix.png"

  @bullets [
    "a TUI inside a LiveView page — no terminal emulator at all",
    "cells over the socket: structured diffs, not ANSI",
    "a ~5KB JS hook paints cells straight into the DOM",
    "pixel regions ride along as PNG: 3D and images at full resolution",
    "full page LiveView, or a LiveComponent inside one",
    "navigation intents: {:navigate, path} from any handler"
  ]

  def title, do: "phoenix_ex_ratatui"

  def notes do
    """
    - first thing wearing a cell session: phoenix_ex_ratatui. same relation as kino to the byte stream
    - no xterm, no ansi. cell diffs over the liveview socket, tiny hook paints spans. ~5KB js
    - 0.3, pixel regions: the hook measures the font's cell size and sends it with the resize -> the session gets a font size -> 3D + images come back as png data urls, one <img> each in a layer over the grid. full res in a browser. the screenshot is /cube in the demo app: spinning cube next to a photo, m toggles both back to cells for the comparison
    - two shapes: LiveView full page, LiveComponent inside a page. same module is the liveview and the app
    - both runtimes
    - handlers return navigate / patch / redirect intents
    - bandwidth: a static screen costs nothing, a ticking dashboard costs the cells that changed. regions only travel when the set changed, so a still picture is free too. halfblock images are the expensive case, png regions are cheaper and sharper
    - a11y: cells are spans in the dom, screen readers see text, not a canvas
    - the room is about to be inside this one in a bit
    """
  end

  def mount(_opts), do: {:ok, %{screenshot: Ui.load_image(@screenshot)}}

  def render(%{screenshot: screenshot}, area) do
    Ui.headline_with_bullets_and_figure(area, "LiveView", @bullets, screenshot, @screenshot)
  end
end
