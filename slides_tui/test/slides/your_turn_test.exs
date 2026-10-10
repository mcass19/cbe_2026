defmodule TuisEverywhere.Slides.YourTurnTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Subscription
  alias ExRatatui.Widgets.BigText
  alias ExRatatui.Widgets.Canvas
  alias ExRatatui.Widgets.Canvas.{Line, Points}
  alias TuisEverywhere.Slides.YourTurn, as: Slide

  @area %Rect{x: 0, y: 0, width: 160, height: 40}

  defp at(n) do
    {:ok, state} = Slide.mount([])

    Enum.reduce(1..n//1, state, fn _, s ->
      {:noreply, s} = Slide.handle_info(:tick, s)
      s
    end)
  end

  defp shapes(state) do
    {%Canvas{marker: :braille, shapes: shapes}, _} =
      Enum.find(Slide.render(state, @area), &match?({%Canvas{}, _}, &1))

    shapes
  end

  # every rat has one eye: a single-point Points in the text colour
  defp rats(state) do
    text = SlidesTui.Theme.current().text
    Enum.count(shapes(state), &match?(%Points{coords: [_], color: ^text}, &1))
  end

  defp cursor?(state) do
    text = SlidesTui.Theme.current().text
    # the cursor's strokes are vertical; no rat line is
    Enum.any?(shapes(state), &match?(%Line{x1: x, x2: x, color: ^text}, &1))
  end

  test "renders the headline over a braille canvas" do
    assert Enum.any?(Slide.render(at(0), @area), &match?({%BigText{}, _}, &1))
    assert shapes(at(0)) != []
  end

  test "three rats on their rockets, then one by one they're gone" do
    assert rats(at(0)) == 3
    assert rats(at(Slide.all_gone_tick())) == 0
    assert rats(at(Slide.cycle_ticks() - 1)) == 0
  end

  test "the launches start over every cycle" do
    assert shapes(at(Slide.cycle_ticks())) == shapes(at(0))
  end

  test "rockets climb up and to the right once they leave the ramp" do
    # the first rat's eye: the leftmost one until it has climbed far
    first_eye = fn state ->
      state
      |> shapes()
      |> Enum.flat_map(fn
        %Points{coords: [eye]} -> [eye]
        _ -> []
      end)
      |> Enum.min()
    end

    {x0, y0} = first_eye.(at(0))
    {x1, y1} = first_eye.(at(20))
    assert x1 > x0 and y1 > y0
  end

  test "the empty seat's cursor blinks" do
    assert cursor?(at(0))
    refute cursor?(at(5))
    assert cursor?(at(10))
  end

  test "keeps one interval subscription while active" do
    assert [%Subscription{message: :tick}] = Slide.subscriptions(at(0))
  end

  test "ignores unrelated info messages" do
    state = at(0)
    assert {:noreply, ^state} = Slide.handle_info(:other, state)
  end
end
