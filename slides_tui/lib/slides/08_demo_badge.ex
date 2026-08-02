defmodule TuisEverywhere.Slides.DemoBadge do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "The badge"

  def notes do
    """
    ## Demo — the badge

    - hold up the badge (or the camera feed of it)
    - Nerves firmware on the Goatmire conference badge hardware —
      credit Gus Workman for the badge itself
    - the screen is e-ink: a cell session renders the TUI, the cells are
      rasterized into the e-ink frame buffer
    - it cycles two screens and inverts colors each phase — that keeps
      every pixel driven, which is what partial-refresh e-ink needs to
      stay ghost-free
    - the point: same library, same widgets, 122x250 pixels of museum
      placard
    """
  end

  def render(_state, area) do
    Ui.demo(area, [
      "a TUI on an e-ink name badge",
      "Nerves + cell session + 8x8 font"
    ])
  end
end
