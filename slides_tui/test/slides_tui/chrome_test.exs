defmodule SlidesTui.ChromeTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.{Block, Paragraph}
  alias SlidesTui.{Chrome, Theme}

  @frame %Rect{x: 0, y: 0, width: 80, height: 24}
  @footer_rect %Rect{x: 0, y: 23, width: 80, height: 1}
  @accent {:rgb, 225, 31, 193}
  @slate {:rgb, 58, 62, 78}
  @chip_style %Style{fg: {:rgb, 248, 248, 242}, bg: @slate, modifiers: [:bold]}
  @violet {:rgb, 167, 139, 250}
  @attribution_style %Style{fg: {:rgb, 98, 114, 164}, modifiers: [:italic]}
  @attribution_name_style %Style{fg: @violet, modifiers: [:italic]}

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

  describe "with another theme" do
    test "border, chips and attribution all take the theme's colours" do
      theme = Theme.fetch!(:daylight)

      assert %Block{border_style: %Style{fg: accent}} = Chrome.body_block("x", theme)
      assert accent == theme.accent

      [{progress, _}, {attribution, _} | _hints] = Chrome.footer(0, 3, @footer_rect, theme)
      assert %Paragraph{style: %Style{fg: fg, bg: bg}} = progress
      assert {fg, bg} == {theme.chip_fg, theme.chip_bg}

      assert %Paragraph{text: %Line{spans: [prefix, name]}} = attribution
      assert {prefix.style.fg, name.style.fg} == {theme.muted, theme.violet}
    end
  end

  describe "footer/3" do
    test "returns one progress chip, one chip per hint, and an attribution" do
      widgets = Chrome.footer(0, 12, @footer_rect)

      # 1 progress + 5 hint chips + 1 attribution = 7 widgets
      assert length(widgets) == 7

      [progress, attribution | hint_chips] = widgets

      # footer chips are for the presenter, not the room: progress and
      # hints share one muted gray-on-slate look
      assert {%Paragraph{text: " 1 / 12 ", style: @chip_style}, _} = progress

      Enum.each(hint_chips, fn {widget, _rect} ->
        assert %Paragraph{style: @chip_style} = widget
      end)

      hint_texts = Enum.map(hint_chips, fn {%Paragraph{text: t}, _} -> t end)

      assert hint_texts == [
               " ←/h prev ",
               " →/l next ",
               " n notes ",
               " t theme ",
               " q quit "
             ]

      # "built with " stays muted; the library name carries the violet so
      # it stands apart from the magenta chrome
      assert {
               %Paragraph{
                 text: %Line{
                   spans: [
                     %Span{content: " built with ", style: @attribution_style},
                     %Span{content: "ex_ratatui ", style: @attribution_name_style}
                   ]
                 },
                 alignment: :center
               },
               _
             } = attribution
    end

    test "progress chip is 1-indexed" do
      assert [{%Paragraph{text: " 1 / 5 "}, _} | _] = Chrome.footer(0, 5, @footer_rect)
      assert [{%Paragraph{text: " 5 / 5 "}, _} | _] = Chrome.footer(4, 5, @footer_rect)
    end

    test "progress on the left, attribution centered, hints flush right" do
      # a projector-wide row: centering needs the hints to fit in the
      # right half beside the attribution
      wide = %Rect{x: 0, y: 23, width: 160, height: 1}

      [{_, p_rect}, {_, attr_rect} | hint_chips] = Chrome.footer(0, 12, wide)
      hint_rects = Enum.map(hint_chips, fn {_, r} -> r end)

      # progress and the last hint each sit one cell in from their edge,
      # so their filled backgrounds never touch the screen edge
      assert p_rect.x == wide.x + 1
      assert List.last(hint_rects).x + List.last(hint_rects).width == wide.x + wide.width - 1

      # the attribution sits in the true center of the row
      left_margin = attr_rect.x - wide.x
      right_margin = wide.x + wide.width - (attr_rect.x + attr_rect.width)
      assert abs(left_margin - right_margin) <= 1

      # left to right: progress, attribution, hints
      assert p_rect.x + p_rect.width <= attr_rect.x
      assert attr_rect.x + attr_rect.width <= hd(hint_rects).x

      hint_rects
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        # consecutive hint chips leave a 1-cell gap between them
        assert b.x - (a.x + a.width) == 1
      end)

      # every segment lives on the footer row
      Enum.each([p_rect, attr_rect | hint_rects], fn r ->
        assert r.y == wide.y
        assert r.height == 1
      end)
    end

    test "a row too narrow for the true center keeps every hint whole" do
      # 100 cols can't fit the hints in the right half beside a centered
      # attribution, so it centers in the gap between chip and hints
      row = %Rect{x: 0, y: 23, width: 100, height: 1}
      [{_, p_rect}, {_, attr_rect} | hint_chips] = Chrome.footer(0, 12, row)

      Enum.each(hint_chips, fn {%Paragraph{text: text}, r} ->
        assert r.width == String.length(text)
      end)

      {_, first_hint} = hd(hint_chips)
      gap_left = attr_rect.x - (p_rect.x + p_rect.width)
      gap_right = first_hint.x - (attr_rect.x + attr_rect.width)
      assert abs(gap_left - gap_right) <= 1
    end

    test "narrow rect still produces all seven widgets" do
      narrow = %Rect{x: 0, y: 0, width: 60, height: 1}
      assert length(Chrome.footer(0, 5, narrow)) == 7
    end
  end
end
