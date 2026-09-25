defmodule TuisEverywhere.Slides.Transports do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Transports"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "One app, any door", [
      "where do the bytes go, where do the events come from",
      "`:local` — the terminal in front of it, crossterm owns the tty",
      "`:ssh` — the BEAM as an SSH server, one isolated session per connection",
      "`:distributed` — attach from another node, the app side never loads the NIF",
      "`Nerves` — all three doors on one firmware",
      "`custom` — small contract: bytes out, events in"
    ])
  end
end
