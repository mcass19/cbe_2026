defmodule TuisEverywhere.Slides.TuisOutThere do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "TUIs out there"

  def notes do
    """
    ## TUIs out there, built with ex_ratatui

    - everything in this talk was one of them: the deck, the badge, the
      lobby everyone is sitting in
    - ash_tui — a TUI explorer for Ash Framework resources
    - bb_tui — a terminal frontend for the bb agent
    - ex_athena — a chat TUI (mix athena.chat)
    - update this list before talk day — it keeps growing, and that is
      the closing argument: the BEAM deserves terminal UIs, and now the
      floor is open
    - call to action: hexdocs.pm/ex_ratatui, examples/ has an isolate
      per widget, come build one
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Built with it", [
      "this deck — slides_tui",
      "the badge on my chest — Nerves + e-ink",
      "the lobby you are sitting in — phoenix_ex_ratatui",
      "ash_tui — explore Ash Framework resources",
      "bb_tui, ex_athena, and counting…"
    ])
  end
end
