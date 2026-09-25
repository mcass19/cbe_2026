defmodule TuisEverywhere.Slides.Observability do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "In production"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Trust it, ship it", [
      "`test` — test_mode {w, h}: the real runtime on a virtual terminal, no TTY, async",
      "`debug` — runtime snapshot, a trace ring buffer, headless buffer inspection",
      "`telemetry` — spans for every phase of the loop, widget counts per frame",
      "`perf` — 16ms poll ≈ 60fps, draw + poll on DirtyIo, quiet frames near free",
      "`ship` — Burrito: one native binary per OS, no Erlang on the user's machine"
    ])
  end
end
