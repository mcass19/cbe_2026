defmodule TuisEverywhere.Slides.DemoTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Subscription
  alias ExRatatui.Widgets.BigText
  alias ExRatatui.Widgets.Canvas
  alias ExRatatui.Widgets.Canvas.Line
  alias TuisEverywhere.Slides.Demo

  @area %Rect{x: 0, y: 0, width: 160, height: 40}

  defp tick(state, n) do
    Enum.reduce(1..n//1, state, fn _, s ->
      {:noreply, s} = Demo.handle_info(:tick, s)
      s
    end)
  end

  defp shapes(state) do
    {%Canvas{marker: :braille, shapes: shapes}, _} =
      Enum.find(Demo.render(state, @area), &match?({%Canvas{}, _}, &1))

    shapes
  end

  test "renders the headline and a braille canvas made of lines" do
    {:ok, state} = Demo.mount([])
    assert Enum.any?(Demo.render(state, @area), &match?({%BigText{}, _}, &1))

    shapes = shapes(state)
    assert shapes != [] and Enum.all?(shapes, &match?(%Line{}, &1))
  end

  test "curtains open, hold, close, pause, and open again" do
    assert Demo.open_fraction(0) == 0.0
    assert Demo.open_fraction(15) == 0.5
    assert Demo.open_fraction(30) == 1.0
    # held open for three swings
    assert Demo.open_fraction(30 + 119) == 1.0
    # closing: halfway after 15 ticks, shut after 30
    assert Demo.open_fraction(30 + 120 + 15) == 0.5
    assert Demo.open_fraction(30 + 120 + 30) == 0.0
    # stays closed until the cycle wraps, then opens again
    assert Demo.open_fraction(Demo.cycle_ticks() - 1) == 0.0
    assert Demo.open_fraction(Demo.cycle_ticks()) == 0.0
    assert Demo.open_fraction(Demo.cycle_ticks() + 15) == 0.5
    # the cycle is a whole number of swings
    assert rem(Demo.cycle_ticks(), 40) == 0
  end

  test "the badge is hidden again once the curtains close" do
    {:ok, state} = Demo.mount([])
    open = shapes(tick(state, 30))
    closed = shapes(tick(state, 30 + 120 + 30))

    assert length(closed) < length(open)
    assert shapes(tick(state, Demo.cycle_ticks() + 30)) == open
  end

  test "the badge appears once the curtains have parted" do
    {:ok, state} = Demo.mount([])
    closed = shapes(state)
    open = shapes(tick(state, 30))

    # frame + seats + curtain folds, then the badge's lines on top
    assert length(open) > length(closed)
  end

  test "the badge swings after the curtains open" do
    {:ok, state} = Demo.mount([])
    assert Demo.angle(0) == 0.0
    assert Demo.angle(10) > 0.0
    assert Demo.angle(30) < 0.0

    open = tick(state, 30)
    assert shapes(tick(open, 10)) != shapes(open)
    assert shapes(tick(open, 40)) == shapes(open)
  end

  test "keeps one interval subscription while active" do
    {:ok, state} = Demo.mount([])
    assert [%Subscription{message: :tick}] = Demo.subscriptions(state)
  end

  test "ignores unrelated info messages" do
    {:ok, state} = Demo.mount([])
    assert {:noreply, ^state} = Demo.handle_info(:other, state)
  end
end
