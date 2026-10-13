defmodule TuisEverywhere.Slides.TuisOutThere do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "TUIs out there"

  def notes do
    """
    - everything today was one: this deck, the badge, the phone, the lobby you're sitting in
    - ash_tui, bb_tui, and the community list
    - and there's room for more...
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Built with it", [
      "this deck — `slides_tui`, on the reducer runtime",
      "the badge and the phone — `nerves` + `raster_ex_ratatui`",
      "`lobby_tui` — ssh + `phoenix_ex_ratatui` + `kino_ex_ratatui`",
      "`ash_tui` + `bb_tui` — Ash explorer, Beam Bots dashboard",
      "community: `ex_athena`, `beamcore`, `caudata`, `extop`, and more…"
    ])
  end
end
