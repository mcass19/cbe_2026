defmodule TuisEverywhere.Slides.RatatuiStory do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Giant shoulders"

  def notes do
    """
    - giant shoulders: ratatui, rust tui library
    - found it early on while learning rust, impressed by how easy it was
    - community maintained: handful of volunteer maintainers, open collective, thousands of stars and crates. all credit to them and to Florian Dehau for tui-rs
    - immediate mode is the trick: every frame is plain data -> plain data can cross into rust once per frame
    - not the only way: term_ui (jido folks, elm-style runtime) and breeze (gazler, liveview-style) are pure beam, no nif. go look at them
    - different trade: i wanted ratatui's renderer + widgets, so a nif to bind the best one
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Ratatui", [
      "Rust's TUI library — the community fork of tui-rs (2023), thriving since",
      "immediate mode: describe the frame, ratatui diffs the rest",
      "rich widgets: paragraphs, tables, charts, canvas, and friends",
      "wanted on the BEAM: processes, supervision, distribution",
      "pure-BEAM options exist too: `term_ui`, `breeze`",
      "`ex_ratatui` — bind the best renderer instead of writing one, via `Rustler`"
    ])
  end
end
