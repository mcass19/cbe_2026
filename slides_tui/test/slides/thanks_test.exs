defmodule TuisEverywhere.Slides.ThanksTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.{BigText, Block, Image, Paragraph}
  alias TuisEverywhere.Slides.{Thanks, Ui}

  @area %Rect{x: 0, y: 0, width: 160, height: 40}
  @cyan {:rgb, 139, 233, 253}

  setup do
    {:ok, state} = Thanks.mount([])
    %{state: state}
  end

  test "asks for questions, then lists the links in cyan, never dim", %{state: state} do
    [{%BigText{}, _}, {%Paragraph{text: [question | rest]}, _} | _figure] =
      Thanks.render(state, @area)

    assert Enum.map_join(question.spans, & &1.content) == "Questions?"

    links = for line <- rest, span <- line.spans, span.content != "", do: span

    assert Enum.map(links, & &1.content) == [
             "hex.pm/packages/ex_ratatui",
             "ex-ratatui.hexdocs.pm",
             "github.com/mcass19/cbe_2026"
           ]

    assert Enum.all?(links, &(&1.style.fg == @cyan and :dim not in &1.style.modifiers))
  end

  test "the feedback QR sits right of the links, a muted label under its frame", %{state: state} do
    assert %Image{} = state.qr

    [_banner, {_links, links_rect}, {%Block{}, frame}, {%Image{}, _}, {label, label_rect}] =
      Thanks.render(state, @area)

    assert frame.x > links_rect.x + links_rect.width
    assert %Paragraph{text: "Feedback!", style: style} = label
    assert style == Ui.subtle_style()
    assert label_rect.y == frame.y + frame.height
  end

  # 120 wide fits "Thanks!" at full size but not the title, so the two
  # only match if they switch together.
  for {w, h, size} <- [{120, 40, :quadrant}, {160, 40, :full}] do
    test "the banner matches the title slide's at #{w}×#{h}", %{state: state} do
      area = %Rect{x: 0, y: 0, width: unquote(w), height: unquote(h)}
      {:ok, title} = TuisEverywhere.Slides.Title.mount([])

      [{%BigText{pixel_size: thanks}, _} | _] = Thanks.render(state, area)
      [{%BigText{pixel_size: opening}, _} | _] = TuisEverywhere.Slides.Title.render(title, area)

      assert thanks == unquote(size)
      assert opening == thanks
    end
  end

  test "without the QR file, a placeholder still gets the label" do
    widgets = Thanks.render(%{qr: nil}, @area)

    assert Enum.any?(widgets, &match?({%Block{title: " placeholder "}, _}, &1))
    assert Enum.any?(widgets, &match?({%Paragraph{text: "Feedback!"}, _}, &1))
  end
end
