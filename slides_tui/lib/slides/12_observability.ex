defmodule TuisEverywhere.Slides.Observability do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Testing & observability"

  def notes do
    """
    ## Testing, debugging, performance, telemetry

    - test_mode: {w, h} runs the real runtime against a virtual
      terminal — full app tests with zero tty, works in CI
    - CellSession snapshots: draw once, take_cells, assert on chars and
      styles — never on escape sequences
    - inject events, snapshot state, trace transitions — both runtimes
      support the same debugging hooks
    - telemetry spans wrap render, event handling, and transport
      connects; attach Telemetry.Metrics and the TUI meters itself
    - performance: layout and drawing are Rust; a frame is one NIF call
      and the diff means quiet frames cost almost nothing
    - upstream, property tests hammer every widget encoder so bad input
      fails in Elixir with a message, not in Rust with a panic
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Trust it", [
      "test_mode {w, h}: the real runtime on a virtual terminal",
      "snapshot cells, not escape codes",
      "inject events, snapshot state, trace transitions",
      "telemetry spans on render / events / transports",
      "Rust does layout + draw: one NIF call per frame"
    ])
  end
end
