defmodule TuisEverywhere.Slides.Title do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.{Layout, Style}
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  def notes do
    """
    ## Opening

    - greet the room
    - this whole deck is a TUI, running live on the BEAM
    - built with slides_tui, a tiny deck runner on top of ex_ratatui —
      everything shown today dogfoods the library
    - n toggles these notes, → / space / clicker advances
    """
  end

  def render(_state, area) do
    bundle = SlidesLayout.center(area, height: 9)

    [banner, _gap, sub] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    subtitle = %Paragraph{
      text: "Code BEAM Europe 2026 — Haarlem\nMauricio Cassola — mcass19.dev",
      alignment: :center,
      style: %Style{modifiers: [:dim]}
    }

    [{Ui.headline("TUIs everywhere"), banner}, {subtitle, sub}]
  end
end
