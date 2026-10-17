defmodule TuisEverywhere.Slides.RatatuiStory do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Giant shoulders"

  def notes do
    """
    - giant shoulders: ratatui, rust tui library. found it while learning rust
    - community maintained: volunteer maintainers, open collective. credit to them and to Florian Dehau for tui-rs
    - immediate mode is the trick: every frame is plain data -> crosses into rust once per frame
    - pure beam: term_ui, breeze, and etui for gleam. no nif, go look at them
    - i wanted ratatui's renderer, so a nif
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Ratatui", [
      "Rust's TUI library, community-run",
      "*immediate mode*: describe the frame",
      "tables, charts, canvas, and friends",
      "pure-BEAM too: `term_ui`, `breeze`",
      "`ex_ratatui`: bind it with `Rustler`"
    ])
  end
end
