defmodule TuisEverywhere.Slides.DemoPhoenix do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "phoenix_ex_ratatui"

  def notes do
    """
    ## Demo — phoenix_ex_ratatui (audience!)

    - the participation moment: put the lobby URL + QR on screen and
      invite everyone in from their phones
    - each browser gets a LiveView; phoenix_ex_ratatui renders the cell
      session into the page and sends taps/keys back
    - everybody shares one world: pick an avatar, walk the theatre, grab
      a seat near the stage
    - when enough people are seated, open the curtains — the stage feed
      shows what the seated crowd posts
    - keep it running in the background for the rest of the talk;
      glance at it before Thanks
    """
  end

  def render(_state, area) do
    Ui.demo(area, [
      "join the theatre lobby from your phone",
      "phoenix_ex_ratatui — one shared TUI world in LiveView",
      "",
      "lobby URL + QR go here on talk day"
    ])
  end
end
