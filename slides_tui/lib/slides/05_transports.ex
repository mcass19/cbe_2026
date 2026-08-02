defmodule TuisEverywhere.Slides.Transports do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Transports"

  def notes do
    """
    ## Transports

    - a transport answers one question: where do the cells go, and where
      do the events come from?
    - :local — the terminal in front of the app; crossterm owns the tty
    - :ssh — the BEAM node runs an SSH daemon; every connection gets its
      own TUI session (dashboards on servers, admin consoles, wargames)
    - :distributed — attach to a running node from another node and the
      TUI renders over distribution; observer energy, zero extra deps
    - custom — the transport contract is small; implement it and any
      byte pipe or surface can host a TUI
    - the punchline: the app module does not change — the transport is
      an option, not an architecture
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Transports", [
      ":local — the terminal in front of it",
      ":ssh — the BEAM as an SSH server, one TUI per connection",
      ":distributed — attach from another node, render over dist",
      "custom — small contract, bring any surface",
      "same app module on every one of them"
    ])
  end
end
