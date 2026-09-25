defmodule TuisEverywhere.Slides.ThemedDeckTest do
  # Not async: every test switches the active theme for this process and
  # draws into a headless terminal, one slide at a time.
  use ExUnit.Case, async: false

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.{Canvas, Viewport3D}
  alias SlidesTui.{Deck, Theme}

  # The size the deck is built for (1080p at ~15pt), inside the border.
  @area %Rect{x: 1, y: 1, width: 188, height: 42}

  defp rendered(slide) do
    state =
      case slide.mount([]) do
        {:ok, state} -> state
      end

    slide.render(state, @area)
  end

  for name <- Theme.names() do
    test "every slide renders and draws under #{name}" do
      :ok = Theme.put(unquote(name))

      for slide <- Deck.discover([]) do
        widgets = rendered(slide)
        terminal = ExRatatui.init_test_terminal(190, 45)
        # draw/2 is where a bad colour or constraint would blow up
        assert :ok = ExRatatui.draw(terminal, widgets), "#{inspect(slide)} failed to draw"
      end
    end

    test "canvases and the 3D scene sit on #{name}'s ground" do
      :ok = Theme.put(unquote(name))
      theme = Theme.current()

      widgets = Enum.flat_map(Deck.discover([]), &rendered/1)

      canvases = for {%Canvas{} = canvas, _} <- widgets, do: canvas
      assert canvases != []
      assert Enum.all?(canvases, &(&1.background_color == theme.ground))

      [viewport] = for {%Viewport3D{} = viewport, _} <- widgets, do: viewport
      assert viewport.scene.background == Theme.rgb(theme.ground)
    end
  end
end
