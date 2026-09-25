defmodule TuisEverywhere.Slides.TuisOutThere do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "TUIs out there"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
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
