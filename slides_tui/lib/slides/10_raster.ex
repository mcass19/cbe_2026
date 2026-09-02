defmodule TuisEverywhere.Slides.Raster do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  @photo "raster.png"

  @bullets [
    "a TUI on a panel that only knows pixels — e-ink, /dev/fb0, no terminal",
    "a surface is one module: geometry from init/1, pixels out in push/2",
    "cells → glyphs from a bitmap font, pixel regions blitted at native size",
    "patches, not frames: only the rectangles that changed reach the panel",
    "pixel formats: 1-bit with tone rules + dither, RGB565, XRGB8888",
    "Linux framebuffer and evdev helpers; buttons and keys in as key presses"
  ]

  def title, do: "raster_ex_ratatui"

  def notes do
    """
    - last clothes for a cell session: a panel that only knows pixels. no terminal, no browser, no bytes at all
    - ex_ratatui stops at cells, it does not drive panels and it should not. raster_ex_ratatui is the layer in between, its own hex package, the newest one. same shape for every panel, only the pixel format is device-specific
    - a surface is one module: init/1 opens the device and says how big it is and how pixels are packed, push/2 writes rectangles. the library starts the app, folds every diff, rasterises, pushes at the pace the panel tolerates, forwards input

    - what the raster does, in order:
    - 1. font. a bitmap font at a fixed cell size, w x h. panel pixels / cell size = the grid. the session is created at that size and told the font size. badge: 6x8 -> 400x300 becomes 66x37. big panel: scale 3 keeps the grid readable
    - 2. grid. keep the last cell seen at every {col, row}, apply each frame's diff on top. 3D and images arrive as ready bitmaps, regions, the full list every frame, so it just replaces the old one
    - 3. rasterise. per cell: stamp the glyph in fg, fill the rest of the block with bg, at {col*w, row*h}. then scale every region over its cells. background first, picture on top. cells under a region are never drawn
    - 4. patches. only the rectangles that changed leave the raster, already packed in the panel's format. a static screen costs nothing, a ticking gauge costs one row. on e-ink diff size is spi time

    - pixel formats: rgb565 and xrgb8888 for colour, straight into /dev/fb0, that is the framebuffer helper. mono for 1-bit: every colour collapses to a tone, :black is ink, named colours keep their terminal meaning, rgb by luminance, reversed inverts. regions go through a bayer dither, that is why a shaded 3D face still reads on paper
    - font: ascii + box drawing hand-drawn, braille + block elements generated from their unicode bit layouts at compile time. that is why Canvas and BigText just work on a badge. a Font behaviour to bring another

    - the photo: pi 4 on the touch display 2, a surface on /dev/fb0, xrgb8888, scale 3, usb keyboard through evdev. the cube is a pixel region at native res, the rest is the 6x8 font scaled up. iex stays on serial, the panel shows the app
    - two consumers, two ways in: the pi runs the surface process, the badge keeps its own screen process and calls the pure core, Raster.apply on every diff. both fine, the core is plain functions
    - the badge is the hard version: no colour, no grey, two buttons. that one is live, next slide
    """
  end

  def mount(_opts), do: {:ok, %{photo: Ui.load_image(@photo)}}

  def render(%{photo: photo}, area) do
    Ui.headline_with_bullets_and_figure(area, "Displays", @bullets, photo, @photo)
  end
end
