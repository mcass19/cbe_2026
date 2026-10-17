defmodule TuisEverywhere.Slides.Raster do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  @photo "raster.png"

  @bullets [
    "*pixels only*: e-ink, `/dev/fb0`",
    "only what changed is pushed",
    "fonts, pixel formats, panels: pluggable",
    "framebuffer: `use Framebuffer.Surface, rotate: 90`",
    "buttons + touch as input",
    {:links, ["hex.pm/packages/raster_ex_ratatui", "raster-ex-ratatui.hexdocs.pm"]}
  ]

  def title, do: "raster_ex_ratatui"

  def notes do
    """
    - PIXELS ONLY: last clothes for a cell session. a panel that only knows pixels: no terminal, no browser, no bytes
    - ex_ratatui stops at cells on purpose. raster is the layer in between
    - WHAT CHANGED: every frame we only get the cells that changed. for each one: draw the letter with a font, pick its colours, turn it into the bytes this screen understands
    - the 3d view and images come as real pictures and get scaled into their spot. the screen only receives the small rectangles that changed, which matters a lot on e-ink
    - PLUGGABLE: three pieces we can swap. each comes with something that already works, plus a behaviour to write our own
    - fonts: a small 6x8 font is built in, with lines, blocks and braille so borders and charts look right. scale it up for big screens, or bring another font
    - formats: how a colour becomes bytes. black and white for e-ink, where pictures get dithered. 16 and 32 bit colour for normal screens. anything else, write one
    - panels: any screen is one module. say how big it is and which format, then write the rectangles we hand over. spi lcd, e-ink controller, whatever
    - FRAMEBUFFER: the common case is already done. one line and it figures out the screen by itself: how big it is, 16 or 32 bits per pixel, the right format for it, a font size that reads well
    - it also gets the linux console out of the way, finds the keyboard, restarts the app if it quits. `rotate:` if the screen is mounted on its side
    - the photo: pi 4 on the touch display 2
    - INPUT: badge buttons, keyboards, touch over evdev -> same key + mouse events a terminal sends. a tap lands on the right cell, even rotated. the app can't tell
    - guides for each one on hexdocs. the demo shows both: badge + fairphone
    """
  end

  def mount(_opts), do: {:ok, %{photo: Ui.load_image(@photo)}}

  def render(%{photo: photo}, area) do
    Ui.headline_with_bullets_and_figure(area, "Displays", @bullets, photo, @photo)
  end
end
