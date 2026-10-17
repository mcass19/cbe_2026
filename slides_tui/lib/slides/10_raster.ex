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
    - PIXELS ONLY: a screen that only knows pixels. no terminal, no browser. e-ink badge, linux framebuffer
    - ex_ratatui stops at cells, raster is the layer in between
    - WHAT CHANGED: takes the cells that changed, draws them as pixels, sends only those rectangles. on e-ink that's what makes it usable
    - PLUGGABLE: font, pixel format, panel. we ship a small font, black and white for e-ink, 16 or 32 bit colour for normal screens. anything else is one behaviour
    - FRAMEBUFFER: one line. finds the screen, its size and colour depth, picks the rest. the pi in the photo
    - INPUT: buttons, keyboards, touch -> the same key + mouse events the app gets in a terminal
    - "let me show you" -> demo
    - CHECKPOINT ~13:15
    """
  end

  def mount(_opts), do: {:ok, %{photo: Ui.load_image(@photo)}}

  def render(%{photo: photo}, area) do
    Ui.headline_with_bullets_and_figure(area, "Displays", @bullets, photo, @photo)
  end
end
