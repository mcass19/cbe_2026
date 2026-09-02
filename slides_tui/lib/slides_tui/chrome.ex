defmodule SlidesTui.Chrome do
  @moduledoc """
  Pure layout and widget builders for the chrome around a slide.

  Every slide is rendered inside a rounded magenta `Block` that fills
  the full body area; the slide's `title/0` (if any) shows as the
  block's title. A 1-row footer at the bottom carries a magenta progress
  chip on the left, one muted chip per key hint in the middle, and a subtle
  italic attribution on the right (muted "built with", library name in
  violet).

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
  # Key hints are for the presenter, not the room. A slate a notch
  # lighter than the terminal ground keeps them legible without adding
  # four more magenta blocks to the footer; the progress chip alone
  # keeps the accent so the magenta stays on the border and one chip.
  @hint_bg {:rgb, 58, 62, 78}
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
  Footer widgets — a magenta progress chip on the left, one muted slate
  chip per key hint in the middle, and an italic attribution on the right ("built with"
  in gray, the library name in violet).

  Returns a list of `{widget, rect}` tuples so the host can splat them
  into its render output. Each segment owns a dedicated horizontal
  slice of the footer row, which lets each chip carry its own
  background and lets the hints breathe between separators.
  """
  @spec footer(non_neg_integer(), pos_integer(), Rect.t()) ::
          [{Paragraph.t(), Rect.t()}]
  def footer(current_index, total, %Rect{} = rect)
      when is_integer(current_index) and is_integer(total) and
             current_index >= 0 and total > 0 do
    segments =
      [{:gap, 1}, {:chip, " #{current_index + 1} / #{total} "}, :flex] ++
        Enum.intersperse(Enum.map(@hints, &{:hint, " #{&1} "}), {:gap, 1}) ++
        [{:gap, 2}, {:attr, " #{@attribution_prefix}#{@attribution_name} "}]

    constraints =
      Enum.map(segments, fn
        :flex -> {:min, 0}
        {:gap, n} -> {:length, n}
        {_kind, text} -> {:length, String.length(text)}
      end)

    rects = Layout.split(rect, :horizontal, constraints)

    segments
    |> Enum.zip(rects)
    |> Enum.flat_map(&build_segment/1)
  end

  defp build_segment({:flex, _rect}), do: []
  defp build_segment({{:gap, _n}, _rect}), do: []

  defp build_segment({{:chip, text}, rect}),
    do: [{%Paragraph{text: text, style: chip_style()}, rect}]

  defp build_segment({{:hint, text}, rect}),
    do: [{%Paragraph{text: text, style: hint_style()}, rect}]

  # The attribution is one Line of two spans: a muted "built with " and
  # the library name in violet. The segment text is only used to size
  # the rect above; the spans carry the padding so the widths agree.
  defp build_segment({{:attr, _text}, rect}) do
    line =
      Line.new([
        Span.new(" #{@attribution_prefix}", style: attribution_style()),
        Span.new("#{@attribution_name} ", style: attribution_name_style())
      ])

    [{%Paragraph{text: line, alignment: :right}, rect}]
  end

  defp chip_style, do: %Style{fg: :black, bg: @accent, modifiers: [:bold]}
  defp hint_style, do: %Style{fg: :gray, bg: @hint_bg, modifiers: [:bold]}
  defp attribution_style, do: %Style{fg: :dark_gray, modifiers: [:italic]}
  defp attribution_name_style, do: %Style{fg: @violet, modifiers: [:italic]}
end
