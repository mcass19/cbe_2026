defmodule SlidesTui.NotesPopupTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.{Block, Clear, Markdown}
  alias SlidesTui.NotesPopup

  @frame %Rect{x: 0, y: 0, width: 80, height: 24}

  describe "overlay/2" do
    test "returns Clear, then Block, then Markdown in that order" do
      assert [
               {%Clear{}, popup_rect},
               {%Block{title: " Notes ", borders: [:all]}, popup_rect2},
               {%Markdown{content: "# Hello"}, inner_rect}
             ] = NotesPopup.overlay("# Hello", @frame)

      assert popup_rect == popup_rect2
      # inner is contained within popup
      assert inner_rect.x > popup_rect.x
      assert inner_rect.y > popup_rect.y
    end

    test "the block repaints the cleared popup in the theme's chip colours" do
      theme = SlidesTui.Theme.fetch!(:midnight)

      [_, {%Block{style: style, border_style: border}, _}, _] =
        NotesPopup.overlay("n", @frame, theme)

      assert {style.fg, style.bg} == {theme.chip_fg, theme.chip_bg}
      assert border.fg == theme.accent
    end

    test "popup is ~70% wide and ~60% tall, centered within the frame" do
      [{_, popup_rect}, _, _] = NotesPopup.overlay("notes", @frame)
      assert popup_rect.width == 56
      assert popup_rect.height == 14
      assert popup_rect.x == 12
      assert popup_rect.y == 5
    end

    test "inner rect insets the popup by 1 on each side for the border" do
      [_, _, {_, inner_rect}] = NotesPopup.overlay("notes", @frame)
      assert inner_rect.x == 13
      assert inner_rect.y == 6
      assert inner_rect.width == 54
      assert inner_rect.height == 12
    end

    test "preserves the markdown content verbatim" do
      md = "## Title\n\n- bullet\n- another"
      [_, _, {%Markdown{content: content}, _}] = NotesPopup.overlay(md, @frame)
      assert content == md
    end
  end
end
