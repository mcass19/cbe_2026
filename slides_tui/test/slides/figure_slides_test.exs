defmodule TuisEverywhere.Slides.FigureSlidesTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Text.{Line, Span}
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

  describe "Ui.bullet_lines/1" do
    test "backticked names come out cyan, markup stripped" do
      [%Line{spans: [_marker | spans]}] = Ui.bullet_lines(["`:local` — the `tty` here"])

      assert [
               %Span{content: ":local", style: %Style{fg: {:rgb, 139, 233, 253}}},
               %Span{content: " — the ", style: plain},
               %Span{content: "tty", style: %Style{fg: {:rgb, 139, 233, 253}}},
               %Span{content: " here"}
             ] = spans

      assert plain.fg == nil
    end

    test "a starred phrase comes out bold magenta, next to cyan names" do
      [%Line{spans: [_marker | spans]}] = Ui.bullet_lines(["`:ssh` is *one more door*"])

      assert [
               %Span{content: ":ssh", style: %Style{fg: {:rgb, 139, 233, 253}}},
               %Span{content: " is "},
               %Span{content: "one more door", style: punch}
             ] = spans

      assert punch.fg == Ui.theme().accent
      assert :bold in punch.modifiers
      assert Ui.item_width("`:ssh` is *one more door*") == String.length(":ssh is one more door")
    end

    test "a links item renders cyan (never dim) and dot-separated" do
      [%Line{spans: [_marker, link]}] = Ui.bullet_lines([{:links, ["a.pm", "b.pm"]}])
      assert %Span{content: "a.pm · b.pm", style: %Style{fg: {:rgb, 139, 233, 253}}} = link
      refute :dim in link.style.modifiers
    end

    test "item_width/1 counts what is on screen" do
      assert Ui.item_width("`:ssh` — x") == String.length(":ssh — x")
      assert Ui.item_width({:links, ["a.pm", "b.pm"]}) == String.length("a.pm · b.pm")
    end
  end

  describe "Ui.bullet_lines/3" do
    test "wraps with a hanging indent, keeps styles, and drops the spacing when too tall" do
      items = ["`aaaa` bbbb cccc", "dddd"]
      [first, second, blank, third] = Ui.bullet_lines(items, 12)

      assert [_marker, %Span{content: "aaaa", style: %Style{fg: cyan}}, %Span{content: " bbbb"}] =
               first.spans

      assert cyan != nil
      assert [%Span{content: "  "}, %Span{content: "cccc"}] = second.spans
      assert blank.spans == []
      assert [_marker, %Span{content: "dddd"}] = third.spans

      assert length(Ui.bullet_lines(items, 12, 3)) == 3
    end
  end

  describe "Ui.figure/2" do
    test "without an image, a 16:9 placeholder box naming the file" do
      assert {:fit, 32, 9, draw} = Ui.figure(nil, "shot.png")
      rect = %Rect{x: 10, y: 5, width: 40, height: 10}

      assert [{%Block{title: " placeholder "}, ^rect}, {%Paragraph{text: hint}, hint_rect}] =
               draw.(rect)

      assert hint =~ "shot.png"
      assert hint_rect.y > rect.y and hint_rect.y < rect.y + rect.height
    end

    test "an image fits at its own aspect, two columns per pixel row" do
      image = Ui.load_image("profile.png")
      assert {:fit, 800, 400, _draw} = Ui.figure(image, "profile.png")
    end

    test "an image sits inside a violet frame that hugs it" do
      image = Ui.load_image("profile.png")
      {:fit, _cols, _rows, draw} = Ui.figure(image, "profile.png")
      violet = Ui.violet()

      # 800:400 inside the 18×8 left by the border is 16×8, so the frame
      # shrinks to 18×10 and centers in the slot
      assert [
               {%Block{borders: [:all], border_style: %{fg: ^violet}},
                %Rect{x: 1, y: 0, width: 18, height: 10}},
               {^image, %Rect{x: 2, y: 1, width: 16, height: 8}}
             ] = draw.(%Rect{x: 0, y: 0, width: 20, height: 10})
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
