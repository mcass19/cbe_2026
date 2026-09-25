defmodule TuisEverywhere.Slides.ThanksTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.{BigText, Paragraph}
  alias TuisEverywhere.Slides.Thanks

  @area %Rect{x: 0, y: 0, width: 160, height: 40}
  @cyan {:rgb, 139, 233, 253}

  test "asks for questions, then lists the links in cyan, never dim" do
    [{%BigText{}, _}, {%Paragraph{text: [question | rest]}, _}] = Thanks.render(nil, @area)

    assert Enum.map_join(question.spans, & &1.content) == "Questions?"

    links = for line <- rest, span <- line.spans, span.content != "", do: span

    assert Enum.map(links, & &1.content) == [
             "hex.pm/packages/ex_ratatui",
             "ex-ratatui.hexdocs.pm",
             "github.com/mcass19/cbe_2026"
           ]

    assert Enum.all?(links, &(&1.style.fg == @cyan and :dim not in &1.style.modifiers))
  end
end
