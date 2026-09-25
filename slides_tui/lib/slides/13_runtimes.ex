defmodule TuisEverywhere.Slides.Runtimes do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Runtimes"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Shape of an app", [
      "`callback` — GenServer-shaped: mount, render, handle_event",
      "`reducer` — Elm-shaped: update(msg, state) + subscriptions",
      "commands and subscriptions keep side effects off the loop",
      "same widgets, same transports — pick per app",
      "this deck runs on the reducer runtime"
    ])
  end
end
