defmodule SlidesTui.Chrome do
  @moduledoc """
  Pure layout and widget builders for the chrome around a slide.

  Every slide is rendered inside a rounded `Block` in the theme's accent
  that fills the full body area; the slide's `title/0` (if any) shows as
  the block's title. A 1-row footer at the bottom carries a muted
  progress chip on the left, a subtle italic attribution in the center
  (muted "built with", library name in violet), and one muted chip per
  key hint on the right.

  All functions here are pure (no side effects, no global state): the
  colours come from the `SlidesTui.Theme` passed in, defaulting to the
  default theme. The host calls `layout/1` once per frame, then uses
  `body_block/2` and `footer/4` to build the chrome widgets.
  """

  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.{Block, Paragraph}
  alias SlidesTui.Theme

  # Footer chips are for the presenter, not the room: the progress chip
  # and the key hints share one muted look (the theme's chip colours),
  # so none of them pulls the eye off the slide. The accent stays on
  # the border.
  @hints ["←/h prev", "→/l next", "n notes", "t theme", "q quit"]
  @attribution_prefix "built with "
  @attribution_name "ex_ratatui"

  @doc """
  Splits `area` into `body`, `inner`, and `footer` rects.

    * `:body` — the rect the body block fills (everything above the
      footer row)
    * `:inner` — the rect inside the body block, inset by 1 cell on
      each side for the rounded border. The active slide's `render/2`
      uses this rect.
    * `:footer` — the bottom 1-row rect
  """
  @spec layout(Rect.t()) :: %{body: Rect.t(), inner: Rect.t(), footer: Rect.t()}
  def layout(%Rect{} = area) do
    [body, footer] = Layout.split(area, :vertical, [{:min, 0}, {:length, 1}])

    inner = %Rect{
      x: body.x + 1,
      y: body.y + 1,
      width: max(body.width - 2, 0),
      height: max(body.height - 2, 0)
    }

    %{body: body, inner: inner, footer: footer}
  end

  @doc """
  Returns the rounded accent-coloured `Block` that wraps a slide's body.
  When `title` is a string it sits in the block's title slot; when `nil`
  the block has no title text but is otherwise identical.
  """
  @spec body_block(String.t() | nil, Theme.t()) :: Block.t()
  def body_block(title, theme \\ Theme.fetch!(Theme.default()))
      when is_binary(title) or is_nil(title) do
    %Block{
      borders: [:all],
      border_type: :rounded,
      border_style: %Style{fg: theme.accent},
      title: block_title(title)
    }
  end

  defp block_title(nil), do: nil
  defp block_title(title), do: " #{title} "

  @doc """
  Footer widgets — a muted progress chip on the left, an italic
  attribution centered on the row ("built with" muted, the library name
  in violet), and one chip of the same look per key hint on the right.

  Returns a list of `{widget, rect}` tuples, left to right, so the host
  can splat them into its render output. Each segment owns a dedicated
  horizontal slice of the footer row, which lets each chip carry its own
  background and lets the hints breathe between separators.
  """
  @spec footer(non_neg_integer(), pos_integer(), Rect.t(), Theme.t()) ::
          [{Paragraph.t(), Rect.t()}]
  def footer(current_index, total, %Rect{} = rect, theme \\ Theme.fetch!(Theme.default()))
      when is_integer(current_index) and is_integer(total) and
             current_index >= 0 and total > 0 do
    attr = {:attr, " #{@attribution_prefix}#{@attribution_name} "}
    progress = [{:gap, 1}, {:chip, " #{current_index + 1} / #{total} "}]
    hints = Enum.intersperse(Enum.map(@hints, &{:hint, " #{&1} "}), {:gap, 1}) ++ [{:gap, 1}]

    # The true center of the row lines up with the centered slide content,
    # but only fits when the wider side (the hints) has room in its half.
    # Narrower rows center the attribution in the gap between the two.
    side = max(total_width(progress), total_width(hints))

    if rect.width >= 2 * side + width(attr) do
      [left, center, right] =
        Layout.split(rect, :horizontal, [{:fill, 1}, {:length, width(attr)}, {:fill, 1}])

      lay_out(progress ++ [:flex], left, theme) ++
        build_segment({attr, center}, theme) ++ lay_out([:flex | hints], right, theme)
    else
      lay_out(progress ++ [:flex, attr, :flex] ++ hints, rect, theme)
    end
  end

  defp total_width(segments), do: segments |> Enum.map(&width/1) |> Enum.sum()

  defp lay_out(segments, rect, theme) do
    rects = Layout.split(rect, :horizontal, Enum.map(segments, &constraint/1))

    segments
    |> Enum.zip(rects)
    |> Enum.flat_map(&build_segment(&1, theme))
  end

  defp constraint(:flex), do: {:fill, 1}
  defp constraint(segment), do: {:length, width(segment)}

  defp width({:gap, n}), do: n
  defp width({_kind, text}), do: String.length(text)

  defp build_segment({:flex, _rect}, _theme), do: []
  defp build_segment({{:gap, _n}, _rect}, _theme), do: []

  defp build_segment({{kind, text}, rect}, theme) when kind in [:chip, :hint],
    do: [
      {%Paragraph{
         text: text,
         style: %Style{fg: theme.chip_fg, bg: theme.chip_bg, modifiers: [:bold]}
       }, rect}
    ]

  # The attribution is one Line of two spans: a muted "built with " and
  # the library name in violet. The segment text is only used to size
  # the rect above; the spans carry the padding so the widths agree.
  defp build_segment({{:attr, _text}, rect}, theme) do
    line =
      Line.new([
        Span.new(" #{@attribution_prefix}", style: %Style{fg: theme.muted, modifiers: [:italic]}),
        Span.new("#{@attribution_name} ", style: %Style{fg: theme.violet, modifiers: [:italic]})
      ])

    [{%Paragraph{text: line, alignment: :center}, rect}]
  end
end
