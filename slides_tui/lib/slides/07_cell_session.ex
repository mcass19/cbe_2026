defmodule TuisEverywhere.Slides.CellSession do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Cell session"

  def notes do
    """
    ## Cell session — non-terminal surfaces

    - the trick behind the last demo: CellSession draws into an
      off-screen buffer instead of a tty
    - a cell is just data — char, fg, bg, modifiers — and data can be
      shipped anywhere: a Livebook output, a LiveView page, an e-ink
      frame buffer
    - events run the same road in reverse: the surface synthesizes
      %Event.Key{} structs and feeds them in
    - the same buffer doubles as the testing story — assert on cells,
      never on escape codes
    - this one transport is what makes "everywhere" honest: the next two
      demos are both cell sessions wearing different clothes
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Cells as data", [
      "no terminal at all — draw into an off-screen cell buffer",
      "a cell is data: char + style, shippable anywhere",
      "Livebook cell, LiveView page, e-ink badge: one TUI",
      "events flow back in as plain structs",
      "the same buffer powers the test story"
    ])
  end
end
