defmodule TuisEverywhere.Slides.Thanks do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.{Layout, Style}
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  def notes do
    """
    ## Wrap up

    - thanks for staying
    - glance at the lobby one last time — wave at the seated crowd
    - slides, lobby, badge firmware: all linked from mcass19.dev
    - library: hexdocs.pm/ex_ratatui
    - questions — and q quits the deck, which feels thematically right
    """
  end

  def render(_state, area) do
    bundle = SlidesLayout.center(area, height: 9)

    [banner, _gap, sub] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    links = %Paragraph{
      text: "Questions?\nmcass19.dev — hexdocs.pm/ex_ratatui",
      alignment: :center,
      style: %Style{modifiers: [:dim]}
    }

    [{Ui.headline("Thanks!"), banner}, {links, sub}]
  end
end
