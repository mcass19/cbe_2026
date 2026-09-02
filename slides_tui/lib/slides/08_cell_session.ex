defmodule TuisEverywhere.Slides.CellSession do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "CellSession"

  def notes do
    """
    - livebook still spoke terminal. now drop it completely: what if there are no bytes at all
    - ratatui draws into an off-screen buffer. no escape codes, no emulator. same draw, same feed_input, same lifecycle as the byte session, just cells out instead of ansi
    - a cell: char, fg, bg, modifiers, and a skip flag. skip is how Popup does transparency. :reset means "whatever the consumer's default is"
    - first diff at 80x24 is 1920 ops, after that only what changed. a red paragraph in a five-wide rect is five changed cells, not one: keep styled rects tight, diff size is bandwidth. on e-ink it is spi time
    - events back in as %Event.Key{} structs. a badge button is a key press, a browser keydown is a key press
    - 0.14, pixel regions: give the session a cell size in pixels -> Viewport3D + Image arrive as real bitmaps, regions, next to the cells. stateless contract: the full list every frame, covered cells blank, longest side capped at 1280px. Region.to_png for text channels. cells for structure, pixels for pictures, like kitty graphics
    - same buffer is the test story: assert on cells, never on escapes
    - this makes "everywhere" honest. next two: cell sessions in different clothes, both built on this and on the regions
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Cells as data", [
      "transports, one level down: what if there are no bytes at all?",
      "no terminal — ratatui draws into an off-screen cell buffer",
      "a cell is data: char + style, every frame a diff, shippable anywhere",
      "events flow back in as plain structs: a button is a key press",
      "give it a cell size in pixels and 3D + images arrive as real bitmaps",
      "the same buffer powers the test story"
    ])
  end
end
