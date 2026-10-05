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
    - events back in as %Event.Key{} structs. a badge button is a key press, a browser keydown is a key press
    - pixel regions: give the session a cell size in pixels -> Viewport3D + Image arrive as real bitmaps, regions, next to the cells
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
