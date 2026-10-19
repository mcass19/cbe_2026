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
    - phoenix turned cells into html. now take the browser away too
    - a screen that only knows pixels. e-ink badge, linux framebuffer, the pi in the photo
    - nobody there to paint for us, so we paint the cells ourselves. that's raster: the second cell session, different clothes
    - same idea as the diffs over the socket. changed cells -> pixels -> push only those rectangles
    - we ship a small font, black and white for e-ink, 16 or 32 bit colour for normal screens. font, pixel format, panel is a behaviour
    - FRAMEBUFFER: one line. finds the screen, its size and colour depth, picks the rest. rotate for screens mounted sideways
    - INPUT: buttons, keyboards, touch -> the same key + mouse events the app gets in a terminal. app still has no idea
    - enough slides, let me show you -> demo
    - CHECKPOINT ~13:15
    """
  end

  def mount(_opts), do: {:ok, %{photo: Ui.load_image(@photo)}}

  def render(%{photo: photo}, area) do
    Ui.headline_with_bullets_and_figure(area, "Displays", @bullets, photo, @photo)
  end
end
