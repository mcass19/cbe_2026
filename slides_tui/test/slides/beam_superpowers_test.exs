defmodule TuisEverywhere.Slides.BeamSuperpowersTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Subscription
  alias ExRatatui.Widgets.BigText
  alias ExRatatui.Widgets.Canvas
  alias ExRatatui.Widgets.Canvas.{Line, Points}
  alias TuisEverywhere.Slides.BeamSuperpowers, as: Slide

  @area %Rect{x: 0, y: 0, width: 160, height: 40}

  defp tick(state, n) do
    Enum.reduce(1..n//1, state, fn _, s ->
      {:noreply, s} = Slide.handle_info(:fly, s)
      s
    end)
  end

  defp canvas(state) do
    {%Canvas{} = canvas, _rect} =
      Enum.find(Slide.render(state, @area), &match?({%Canvas{}, _}, &1))

    canvas
  end

  # the rocket's leftmost point — a proxy for how far along it is
  defp rocket_x(state) do
    state
    |> canvas()
    |> Map.fetch!(:shapes)
    |> Enum.filter(&match?(%Line{}, &1))
    |> Enum.flat_map(&[&1.x1, &1.x2])
    |> Enum.min()
  end

  test "renders the headline and a braille canvas with stars and a rocket" do
    {:ok, state} = Slide.mount([])
    widgets = Slide.render(state, @area)

    assert Enum.any?(widgets, &match?({%BigText{}, _}, &1))

    %Canvas{marker: :braille, shapes: shapes} = canvas(state)
    assert Enum.any?(shapes, &match?(%Points{}, &1))
    assert Enum.count(shapes, &match?(%Line{}, &1)) > 5
  end

  test "a rat in the text colour rides on the rocket" do
    {:ok, state} = Slide.mount([])
    text = SlidesTui.Theme.current().text
    shapes = canvas(tick(state, 30)).shapes

    rat = Enum.filter(shapes, &match?(%Line{color: ^text}, &1))
    hull = Enum.filter(shapes, &match?(%Line{color: c} when c != text, &1))
    assert length(rat) > 5
    assert Enum.any?(shapes, &match?(%Points{coords: [_eye], color: ^text}, &1))

    # it rides along: every rat point sits within the rocket's reach
    {hull_xs, hull_ys} = hull |> Enum.flat_map(&[{&1.x1, &1.y1}, {&1.x2, &1.y2}]) |> Enum.unzip()

    for %Line{x1: x, y1: y} <- rat do
      assert x > Enum.min(hull_xs) - 10 and x < Enum.max(hull_xs) + 10
      assert y > Enum.min(hull_ys) - 10 and y < Enum.max(hull_ys) + 10
    end
  end

  test "the rocket climbs to the right on every tick" do
    {:ok, state} = Slide.mount([])
    x0 = rocket_x(state)
    x10 = rocket_x(tick(state, 10))
    x20 = rocket_x(tick(state, 20))

    assert x0 < x10
    assert x10 < x20
  end

  test "the flight loops back to the start" do
    {:ok, state} = Slide.mount([])
    assert rocket_x(tick(state, Slide.flight_ticks())) == rocket_x(state)
  end

  test "keeps one interval subscription while active" do
    {:ok, state} = Slide.mount([])
    assert [%Subscription{message: :fly}] = Slide.subscriptions(state)
  end

  test "ignores unrelated info messages" do
    {:ok, state} = Slide.mount([])
    assert {:noreply, ^state} = Slide.handle_info(:other, state)
  end
end
