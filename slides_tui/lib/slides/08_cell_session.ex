defmodule TuisEverywhere.Slides.CellSession do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "CellSession"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
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
