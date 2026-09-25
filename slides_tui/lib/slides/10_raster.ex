defmodule TuisEverywhere.Slides.Raster do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  @photo "raster.png"

  @bullets [
    "a TUI on a panel that only knows pixels — e-ink, `/dev/fb0`, no terminal",
    "any panel is one module: geometry from `init/1`, pixels out in `push/2`",
    "a Linux framebuffer is one line: `use Framebuffer.Surface, rotate: 90`",
    "cells → glyphs from a bitmap font, pixel regions blitted at native size",
    "patches, not frames: only the rectangles that changed reach the panel",
    "pixel formats: 1-bit with tone rules + dither, RGB565, XRGB8888",
    "keyboards and touch over `evdev`: a button is a key press, a tap a click",
    {:links, ["hex.pm/packages/raster_ex_ratatui", "raster-ex-ratatui.hexdocs.pm"]}
  ]

  def title, do: "raster_ex_ratatui"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def mount(_opts), do: {:ok, %{photo: Ui.load_image(@photo)}}

  def render(%{photo: photo}, area) do
    Ui.headline_with_bullets_and_figure(area, "Displays", @bullets, photo, @photo)
  end
end
