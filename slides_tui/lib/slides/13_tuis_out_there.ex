defmodule TuisEverywhere.Slides.TuisOutThere do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "TUIs out there"

  def notes do
    """
    - everything today was one: this deck, the badge, the pi, the lobby you're sitting in
    - whole other talk in the box: two runtimes (this deck is the reducer one), images + 3D, markdown, mouse, custom widgets in pure elixir, headless tests, telemetry, burrito binaries. all in the docs
    - ash_tui, bb_tui, and the community list
    - contributions already happen, textarea wrapping came from outside. widgets need no rust
    - the beam deserves tuis. come build one
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Built with it", [
      "this deck — `slides_tui`, on the reducer runtime",
      "the badge and the phone — `nerves` + `raster_ex_ratatui`",
      "`lobby_tui` — ssh + `phoenix_ex_ratatui` + `kino_ex_ratatui`",
      "`ash_tui` + `bb_tui` — Ash explorer, Beam Bots dashboard",
      "community: `ex_athena`, `beamcore`, `switchyard`, `caudata`, `extop`, `phoenix_gen_api_tui`… yours!?"
    ])
  end
end
