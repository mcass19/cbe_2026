defmodule TuisEverywhere.Slides.CellSession do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "CellSession"

  def notes do
    """
    - livebook still spoke terminal. now drop it completely: what if there are no bytes at all
    - ratatui draws into an off-screen buffer. no escape codes, no emulator. cells out instead of ansi
    - a cell is char + style
    - events back in as %Event.Key{} structs. a badge button is a key press, a browser keydown is a key press
    - pixel regions: Viewport3D + Image arrive as real bitmaps next to the cells
    - same buffer is the test story: assert on cells, never on escapes
    - this makes "everywhere" honest. next two: cell sessions in different clothes
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Cells as data", [
      "*no terminal, no bytes*",
      "a cell is data: char + style",
      "keys come back as structs",
      "pixels → real bitmaps",
      "same buffer, same tests"
    ])
  end
end
