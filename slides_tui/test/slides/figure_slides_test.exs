defmodule TuisEverywhere.Slides.FigureSlidesTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.{BigText, Block, Image, Paragraph}
  alias TuisEverywhere.Slides.{Kino, Lobby, Phoenix, Raster, Ui}

  @area %Rect{x: 0, y: 0, width: 160, height: 40}

  describe "Ui.load_image/1" do
    test "returns an image widget for a file under priv/slides" do
      assert %Image{} = Ui.load_image("profile.png")
    end

    test "returns nil for a missing file" do
      assert Ui.load_image("does_not_exist.png") == nil
    end
  end

  describe "Ui.figure/3" do
    test "draws a placeholder box naming the file when there is no image" do
      rect = %Rect{x: 10, y: 5, width: 40, height: 10}

      assert [{%Block{title: " placeholder "}, ^rect}, {%Paragraph{text: hint}, hint_rect}] =
               Ui.figure(nil, "shot.png", rect)

      assert hint =~ "shot.png"
      assert hint_rect.y > rect.y and hint_rect.y < rect.y + rect.height
    end

    test "places the image when there is one" do
      image = Ui.load_image("profile.png")
      rect = %Rect{x: 0, y: 0, width: 20, height: 10}
      assert [{^image, ^rect}] = Ui.figure(image, "profile.png", rect)
    end
  end

  # Screenshots land in priv/slides/ one by one as the deck gets its
  # figures, so these never depend on which files exist: the mounted
  # state is either an image or nil, and render/2 handles both.
  for slide <- [Kino, Phoenix, Raster, Lobby] do
    test "#{inspect(slide)} mounts and renders its figure or a placeholder" do
      {:ok, state} = unquote(slide).mount([])
      assert [{_key, figure}] = Map.to_list(state)
      assert is_nil(figure) or match?(%Image{}, figure)

      widgets = unquote(slide).render(state, @area)
      assert Enum.any?(widgets, &match?({%BigText{}, _}, &1))

      figure_shown? =
        Enum.any?(widgets, &match?({%Image{}, _}, &1)) or
          Enum.any?(widgets, &match?({%Block{title: " placeholder "}, _}, &1))

      assert figure_shown?
    end

    test "#{inspect(slide)} renders a placeholder when the screenshot is missing" do
      {:ok, state} = unquote(slide).mount([])
      [key] = Map.keys(state)
      widgets = unquote(slide).render(Map.put(state, key, nil), @area)

      assert Enum.any?(widgets, &match?({%Block{title: " placeholder "}, _}, &1))
      refute Enum.any?(widgets, &match?({%Image{}, _}, &1))
    end
  end
end
