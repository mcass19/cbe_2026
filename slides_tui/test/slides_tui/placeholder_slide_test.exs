defmodule SlidesTui.PlaceholderSlideTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.PlaceholderSlide

  test "implements SlidesTui.Slide" do
    behaviours =
      PlaceholderSlide.__info__(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    assert SlidesTui.Slide in behaviours
  end

  test "render/2 returns a single centered dim Paragraph over the given area" do
    area = %Rect{x: 0, y: 0, width: 80, height: 24}
    assert [{%Paragraph{} = p, ^area}] = PlaceholderSlide.render(nil, area)

    assert p.alignment == :center
    assert p.style == %Style{modifiers: [:dim]}
    assert p.text =~ "No slides found"
    assert p.text =~ "lib/slides/"
    assert p.text =~ "q to quit"
  end

  test "inherits Slide default callbacks (no-ops)" do
    assert PlaceholderSlide.mount([]) == {:ok, nil}
    assert PlaceholderSlide.handle_event(:any, :state) == {:noreply, :state}
    assert PlaceholderSlide.handle_info(:any, :state) == {:noreply, :state}
    assert PlaceholderSlide.subscriptions(:state) == []
    assert PlaceholderSlide.title() == nil
    assert PlaceholderSlide.notes() == nil
  end
end
