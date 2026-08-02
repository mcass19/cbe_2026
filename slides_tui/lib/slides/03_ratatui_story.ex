defmodule TuisEverywhere.Slides.RatatuiStory do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Ratatui story"

  def notes do
    """
    ## Ratatui story

    - ratatui: Rust's TUI library, the community fork of tui-rs (2023)
    - immediate mode: describe the whole frame every time, the library
      diffs and writes only what changed
    - huge widget set and ecosystem — tables, charts, canvas, and a
      constellation of companion crates (images, textarea, markdown, 3d)
    - the itch: I wanted those UIs, but with BEAM superpowers —
      processes, supervision, distribution, hot code
    - so instead of rewriting a renderer in Elixir, bind the best one:
      ex_ratatui was born as a Rustler experiment and grew from there
    - credit where due: the ratatui maintainers and the crates ex_ratatui
      vendors (ratatui-image, tui-markdown, ratatui-3d, tui-big-text…)
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Ratatui", [
      "Rust's TUI library — the community fork of tui-rs (2023)",
      "immediate mode: describe the frame, the library diffs the rest",
      "rich widgets: paragraphs, tables, charts, canvas, and friends",
      "wanted on the BEAM: processes, supervision, distribution",
      "ex_ratatui — Elixir bindings, standing on ratatui's shoulders"
    ])
  end
end
