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
    "full page LiveView, or a `LiveComponent` inside one",
    "navigation intents: `{:navigate, path}` from any handler",
    {:links, ["hex.pm/packages/phoenix_ex_ratatui", "phoenix-ex-ratatui.hexdocs.pm"]}
  ]

  def title, do: "phoenix_ex_ratatui"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def mount(_opts), do: {:ok, %{screenshot: Ui.load_image(@screenshot)}}

  def render(%{screenshot: screenshot}, area) do
    Ui.headline_with_bullets_and_figure(area, "LiveView", @bullets, screenshot, @screenshot)
  end
end
