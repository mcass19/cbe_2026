defmodule SlidesTui.Chrome do
  @moduledoc """
  Pure layout and widget builders for the chrome around a slide.

  Every slide is rendered inside a rounded magenta `Block` that fills
  the full body area; the slide's `title/0` (if any) shows as the
  block's title. A 1-row footer at the bottom carries a muted progress
  chip on the left, a subtle italic attribution in the center (muted
  "built with", library name in violet), and one muted chip per key hint
  on the right.

  All functions here are pure (no side effects, no global state).
  The host calls `layout/1` once per frame, then uses `body_block/1`
  and `footer/3` to build the chrome widgets.
  """

  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.{Block, Paragraph}

  # Code BEAM Europe magenta — the same accent lobby_tui uses (#e11fc1),
  # so every TUI in the talk shares one identity color. RGB rather than
  # named `:magenta`, which reads differently across terminal themes.
  @accent {:rgb, 225, 31, 193}
  # Second hue from the same family (#a78bfa): a lighter violet for the
  # library name so it reads as Elixir-flavoured yet distinct from the
  # magenta chrome around it. Light enough to survive italics on a dark
  # ground; Elixir's official #4e2a8e would sink into it.
  @violet {:rgb, 167, 139, 250}
  # Footer chips are for the presenter, not the room: the progress chip
  # and the key hints share one muted look, a slate a notch lighter than
  # the terminal ground, so none of them pulls the eye off the slide.
  # Magenta on slate read dimmer than the gray; the accent stays on the
  # border.
  @chip_bg {:rgb, 58, 62, 78}
  @hints ["←/h prev", "→/l next", "n notes", "q quit"]
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
  Returns the rounded violet `Block` that wraps a slide's body. When
  `title` is a string it sits in the block's title slot; when `nil`
  the block has no title text but is otherwise identical.
  """
  @spec body_block(String.t() | nil) :: Block.t()
  def body_block(title) when is_binary(title) or is_nil(title) do
    %Block{
      borders: [:all],
      border_type: :rounded,
      border_style: %Style{fg: @accent},
      title: block_title(title)
    }
  end

  defp block_title(nil), do: nil
  defp block_title(title), do: " #{title} "

  @doc """
  Footer widgets — a muted slate progress chip on the left, an italic
  attribution centered on the row ("built with" in gray, the library
  name in violet), and one chip of the same look per key hint on the
  right.

  Returns a list of `{widget, rect}` tuples, left to right, so the host
  can splat them into its render output. Each
  segment owns a dedicated horizontal slice of the footer row, which
  lets each chip carry its own background and lets the hints breathe
  between separators.
  """
  @spec footer(non_neg_integer(), pos_integer(), Rect.t()) ::
          [{Paragraph.t(), Rect.t()}]
  def footer(current_index, total, %Rect{} = rect)
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

      lay_out(progress ++ [:flex], left) ++
        build_segment({attr, center}) ++ lay_out([:flex | hints], right)
    else
      lay_out(progress ++ [:flex, attr, :flex] ++ hints, rect)
    end
  end

  defp total_width(segments), do: segments |> Enum.map(&width/1) |> Enum.sum()

  defp lay_out(segments, rect) do
    rects = Layout.split(rect, :horizontal, Enum.map(segments, &constraint/1))

    segments
    |> Enum.zip(rects)
    |> Enum.flat_map(&build_segment/1)
  end

  defp constraint(:flex), do: {:fill, 1}
  defp constraint(segment), do: {:length, width(segment)}

  defp width({:gap, n}), do: n
  defp width({_kind, text}), do: String.length(text)

  defp build_segment({:flex, _rect}), do: []
  defp build_segment({{:gap, _n}, _rect}), do: []

  defp build_segment({{kind, text}, rect}) when kind in [:chip, :hint],
    do: [{%Paragraph{text: text, style: chip_style()}, rect}]

  # The attribution is one Line of two spans: a muted "built with " and
  # the library name in violet. The segment text is only used to size
  # the rect above; the spans carry the padding so the widths agree.
  defp build_segment({{:attr, _text}, rect}) do
    line =
      Line.new([
        Span.new(" #{@attribution_prefix}", style: attribution_style()),
        Span.new("#{@attribution_name} ", style: attribution_name_style())
      ])

    [{%Paragraph{text: line, alignment: :center}, rect}]
  end

  defp chip_style, do: %Style{fg: :gray, bg: @chip_bg, modifiers: [:bold]}
  defp attribution_style, do: %Style{fg: :dark_gray, modifiers: [:italic]}
  defp attribution_name_style, do: %Style{fg: @violet, modifiers: [:italic]}
end
