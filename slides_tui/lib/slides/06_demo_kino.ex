defmodule TuisEverywhere.Slides.DemoKino do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "kino_ex_ratatui"

  def notes do
    """
    ## Demo — kino_ex_ratatui

    - switch to Livebook (have it open and connected beforehand)
    - run the prepared notebook: a TUI rendering inside a notebook cell,
      keyboard events flowing back from the browser
    - point out there is no terminal anywhere in that path
    - tease: "how does a terminal UI run without a terminal?" — answer
      on the next slide
    """
  end

  def render(_state, area) do
    Ui.demo(area, [
      "kino_ex_ratatui — a TUI inside a Livebook cell",
      "no terminal anywhere in sight"
    ])
  end
end
