defmodule TuisEverywhere.Slides.TuisOutThere do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "TUIs out there"

  def notes do
    """
    - everything in this talk was one: the deck, the badge, the pi, the lobby everyone is in
    - the ecosystem: kino, phoenix, raster. three packages on hex, same app module under all of them
    - ash_tui: ash framework explorer
    - bb_tui: dashboard for beam bots robots
    - examples/: eight folders, ~49 scripts, one per widget. start-here path: hello -> counter -> reducer counter -> chat
    - contributions already happen: textarea wrapping in 0.16 came from outside. widgets need no rust
    - the beam deserves tuis, floor is open. i have a lot of ideas. come build one
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Built with it", [
      "this deck — `slides_tui`",
      "the badge and the pi — `nerves` + `raster_ex_ratatui`",
      "`lobby_tui` — ssh + `phoenix_ex_ratatui` + `kino_ex_ratatui`",
      "`ash_tui` — explore Ash Framework resources",
      "`bb_tui` — terminal-based dashboard for Beam Bots robots",
      "community: `ex_athena`, `beamcore`, `switchyard`, `caudata`, `extop`, `phoenix_gen_api_tui`… yours!?"
    ])
  end
end
