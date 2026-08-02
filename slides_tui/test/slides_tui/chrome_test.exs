defmodule SlidesTui.ChromeTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Widgets.{Block, Paragraph}
  alias SlidesTui.Chrome

  @frame %Rect{x: 0, y: 0, width: 80, height: 24}
  @footer_rect %Rect{x: 0, y: 23, width: 80, height: 1}
  @accent {:rgb, 225, 31, 193}
  @chip_style %Style{fg: :black, bg: @accent, modifiers: [:bold]}
  @attribution_style %Style{fg: :dark_gray, modifiers: [:italic]}

  describe "layout/1" do
    test "body fills everything above the 1-row footer" do
      assert %{body: body, inner: inner, footer: footer} = Chrome.layout(@frame)
      assert body == %Rect{x: 0, y: 0, width: 80, height: 23}
      assert footer == @footer_rect
      # inner is body inset by 1 on each side for the rounded border
      assert inner == %Rect{x: 1, y: 1, width: 78, height: 21}
    end

    test "regions tile vertically without gaps or overlap" do
      assert %{body: b, footer: f} = Chrome.layout(@frame)
      assert b.y + b.height == f.y
      assert b.height + f.height == @frame.height
    end

    test "inner sits strictly inside body" do
      assert %{body: b, inner: i} = Chrome.layout(@frame)
      assert i.x > b.x
      assert i.y > b.y
      assert i.x + i.width < b.x + b.width
      assert i.y + i.height < b.y + b.height
    end
  end

  describe "body_block/1" do
    test "returns a rounded magenta Block with the title set" do
      assert %Block{
               borders: [:all],
               border_type: :rounded,
               border_style: %Style{fg: @accent},
               title: " Welcome "
             } = Chrome.body_block("Welcome")
    end

    test "nil title leaves Block.title as nil (no title text)" do
      assert %Block{title: nil, border_type: :rounded} = Chrome.body_block(nil)
    end
  end

  describe "footer/3" do
    test "returns one progress chip, one chip per hint, and an attribution" do
      widgets = Chrome.footer(0, 12, @footer_rect)

      # 1 progress + 4 hint chips + 1 attribution = 6 widgets
      assert length(widgets) == 6

      [progress | rest] = widgets
      {hint_chips, [attribution]} = Enum.split(rest, 4)

      assert {%Paragraph{text: " 1 / 12 ", style: @chip_style}, _} = progress

      Enum.each(hint_chips, fn {widget, _rect} ->
        assert %Paragraph{style: @chip_style} = widget
      end)

      hint_texts = Enum.map(hint_chips, fn {%Paragraph{text: t}, _} -> t end)

      assert hint_texts == [
               " ←/h prev ",
               " →/l next ",
               " n notes ",
               " q quit "
             ]

      assert {
               %Paragraph{
                 text: " built with ex_ratatui ",
                 style: @attribution_style,
                 alignment: :right
               },
               _
             } = attribution
    end

    test "progress chip is 1-indexed" do
      assert [{%Paragraph{text: " 1 / 5 "}, _} | _] = Chrome.footer(0, 5, @footer_rect)
      assert [{%Paragraph{text: " 5 / 5 "}, _} | _] = Chrome.footer(4, 5, @footer_rect)
    end

    test "rects tile horizontally left-to-right and end flush with the right edge" do
      [{_, p_rect} | rest] = Chrome.footer(0, 12, @footer_rect)
      {hint_rects, [{_, attr_rect}]} = Enum.split(rest, 4)

      # progress hugs the left edge of the footer
      assert p_rect.x == @footer_rect.x

      # hints come after the progress chip + flex gap, in order
      assert p_rect.x + p_rect.width <= elem(hd(hint_rects), 1).x

      hint_rects
      |> Enum.map(fn {_, r} -> r end)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        # consecutive hint chips leave a 1-cell gap between them
        assert b.x - (a.x + a.width) == 1
      end)

      # attribution hugs the right edge of the footer
      assert attr_rect.x + attr_rect.width == @footer_rect.x + @footer_rect.width

      # every segment lives on the footer row
      all = [p_rect | Enum.map(hint_rects, fn {_, r} -> r end)] ++ [attr_rect]

      Enum.each(all, fn r ->
        assert r.y == @footer_rect.y
        assert r.height == 1
      end)
    end

    test "narrow rect still produces all six widgets" do
      narrow = %Rect{x: 0, y: 0, width: 60, height: 1}
      assert length(Chrome.footer(0, 5, narrow)) == 6
    end
  end
end
