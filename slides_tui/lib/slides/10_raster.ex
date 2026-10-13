defmodule TuisEverywhere.Slides.Raster do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  @photo "raster.png"

  @bullets [
    "*pixels only*: e-ink, `/dev/fb0`",
    "one module per panel",
    "framebuffer: `use Framebuffer.Surface, rotate: 90`",
    "only what changed is pushed",
    "buttons + touch as input",
    {:links, ["hex.pm/packages/raster_ex_ratatui", "raster-ex-ratatui.hexdocs.pm"]}
  ]

  def title, do: "raster_ex_ratatui"

  def notes do
    """
    - last clothes for a cell session: a panel that only knows pixels. no terminal, no browser, no bytes at all
    - ex_ratatui stops at cells, it does not drive panels and it should not. raster_ex_ratatui is the layer in between
    - any panel is one module: init/1 opens the device and says how big it is and how pixels are packed, push/2 writes rectangles. the library starts the app, folds every diff, rasterises, pushes at the pace the panel tolerates, forwards input, restarts the app when it quits
    - a linux framebuffer is one line: `use RasterExRatatui.Framebuffer.Surface, app: MyApp, rotate: 90`
    - the photo: pi 4 on the touch display 2
    """
  end

  def mount(_opts), do: {:ok, %{photo: Ui.load_image(@photo)}}

  def render(%{photo: photo}, area) do
    Ui.headline_with_bullets_and_figure(area, "Displays", @bullets, photo, @photo)
  end
end
