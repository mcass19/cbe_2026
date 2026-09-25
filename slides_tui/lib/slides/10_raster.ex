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
    - last clothes for a cell session: a panel that only knows pixels. no terminal, no browser, no bytes at all
    - ex_ratatui stops at cells, it does not drive panels and it should not. raster_ex_ratatui is the layer in between, its own hex package, 0.3 now. same shape for every panel, only the pixel format is device-specific
    - any panel is one module: init/1 opens the device and says how big it is and how pixels are packed, push/2 writes rectangles. the library starts the app, folds every diff, rasterises, pushes at the pace the panel tolerates, forwards input, restarts the app when it quits
    - a linux framebuffer is one line: `use RasterExRatatui.Framebuffer.Surface, app: MyApp, rotate: 90`. waits for /dev/fb0, geometry + depth from sysfs, format + font scale picked, console detached, keyboard and touch found over evdev and found again after an unplug. every default is an option or an override

    - what the raster does, in order:
    - 1. font. a bitmap font at a fixed cell size, w x h. panel pixels / cell size = the grid. the session is created at that size and told the font size. badge: 6x8 -> 400x300 becomes 66x37. big panel: scale 3 keeps the grid readable
    - 2. grid. keep the last cell seen at every {col, row}, apply each frame's diff on top. 3D and images arrive as ready bitmaps, regions, the full list every frame, so it just replaces the old one
    - 3. rasterise. per cell: stamp the glyph in fg, fill the rest of the block with bg, at {col*w, row*h}. then scale every region over its cells. background first, picture on top. cells under a region are never drawn
    - 4. patches. only the rectangles that changed leave the raster, already packed in the panel's format. a static screen costs nothing, a ticking gauge costs one row. on e-ink diff size is spi time

    - pixel formats: rgb565 and xrgb8888 for colour, straight into /dev/fb0, that is the framebuffer helper. mono for 1-bit: every colour collapses to a tone, :black is ink, named colours keep their terminal meaning, rgb by luminance, reversed inverts. regions go through a bayer dither, that is why a shaded 3D face still reads on paper
    - font: ascii + box drawing hand-drawn, braille + block elements generated from their unicode bit layouts at compile time. that is why Canvas and BigText just work on a badge. a Font behaviour to bring another
    - rotation: `rotate: 90` turns the app for a panel on its side, the panel is still written in its own orientation. glyphs turn once into the cache, cells cost the same turned as flat. regions were the expensive part, gathered pixel by pixel in elixir, 2x on the pi. 0.15 turns the bitmap in rust, one pass: 95 -> 55 ms a frame, against 43 flat
    - touch: evdev multitouch -> %Event.Mouse{} on the cell under the finger, at any rotation. down, up, drag. the app sees clicks, it has no idea there is a panel

    - the photo: pi 4 on the touch display 2, one `use`. /dev/fb0 rgb565 at 720x1280, rotate 270 for the stand, scale 2 picked from the long side, keyboard + touch over evdev. the cube and the photo are pixel regions at native res, the rest is the 6x8 font scaled up. drag turns the cube, swipe changes the photo, tap switches the tab. iex stays on serial, the panel shows the app
    - two consumers, two ways in: the pi runs the surface process, the badge keeps its own screen process and runs the app with Session from there: every render arrives as a message, handle/2 folds it into patches, a crash leaves a crash frame on the panel. both fine, the core is plain functions
    - the badge is the hard version: no colour, no grey, two buttons. that one is live, next slide
    """
  end

  def mount(_opts), do: {:ok, %{photo: Ui.load_image(@photo)}}

  def render(%{photo: photo}, area) do
    Ui.headline_with_bullets_and_figure(area, "Displays", @bullets, photo, @photo)
  end
end
