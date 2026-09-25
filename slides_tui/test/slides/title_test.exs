defmodule TuisEverywhere.Slides.TitleTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Subscription
  alias ExRatatui.Style
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.{BigText, Paragraph}
  alias TuisEverywhere.Slides.Title

  @area %Rect{x: 0, y: 0, width: 120, height: 30}
  @violet {:rgb, 167, 139, 250}
  # "TUIs everywhere" minus the space
  @letters 14

  defp tick(state, n) do
    Enum.reduce(1..n//1, state, fn _, s ->
      {:noreply, s} = Title.handle_info(:paint, s)
      s
    end)
  end

  defp headline_spans(state) do
    [{%BigText{lines: [%Line{spans: spans}]}, _rect} | _] = Title.render(state, @area)
    spans
  end

  defp painted(state) do
    state
    |> headline_spans()
    |> Enum.filter(&(&1.style.fg == @violet))
    |> Enum.map_join(& &1.content)
  end

  test "mounts unpainted and reads the full title as one span per character" do
    {:ok, state} = Title.mount([])
    spans = headline_spans(state)

    assert Enum.map_join(spans, & &1.content) == "TUIs everywhere"
    assert Enum.all?(spans, &(String.length(&1.content) == 1))
    assert painted(state) == ""
  end

  test "each paint tick colours one more letter, left to right, skipping the space" do
    {:ok, state} = Title.mount([])

    assert painted(tick(state, 1)) == "T"
    assert painted(tick(state, 4)) == "TUIs"
    # the space is never painted, so five ticks reach into the second word
    assert painted(tick(state, 5)) == "TUIse"
    assert painted(tick(state, @letters)) == "TUIseverywhere"
  end

  test "holds the fully painted title for a beat, then starts over" do
    {:ok, state} = Title.mount([])
    full = tick(state, @letters)

    held = tick(full, Title.hold_ticks())
    assert painted(held) == "TUIseverywhere"

    assert painted(tick(held, 1)) == ""
    assert painted(tick(held, 2)) == "T"
  end

  test "names the speaker above the event line" do
    {:ok, state} = Title.mount([])
    [_headline, {%Paragraph{text: [who, _blank, where]}, _rect}] = Title.render(state, @area)

    assert Enum.map_join(who.spans, & &1.content) == "Mauricio Cassola · mcass19"

    assert %Span{content: "mcass19", style: %Style{fg: {:rgb, 139, 233, 253}}} =
             List.last(who.spans)

    assert Enum.map_join(where.spans, & &1.content) =~ "Code BEAM Europe 2026 · Haarlem"
  end

  test "keeps one interval subscription while active" do
    {:ok, state} = Title.mount([])
    assert [%Subscription{} = sub] = Title.subscriptions(state)
    assert sub.message == :paint
  end

  test "ignores unrelated info messages" do
    {:ok, state} = Title.mount([])
    assert {:noreply, ^state} = Title.handle_info(:something_else, state)
  end
end
