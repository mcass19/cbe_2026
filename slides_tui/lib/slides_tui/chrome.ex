defmodule SlidesTui.Chrome do
  @moduledoc """
  Pure layout and widget builders for the chrome around a slide.

  Every slide is rendered inside a rounded magenta `Block` that fills
  the full body area; the slide's `title/0` (if any) shows as the
  block's title. A 1-row footer at the bottom carries a progress chip
  on the left, one chip per key hint in the middle, and a subtle
  italic attribution on the right.

  All functions here are pure (no side effects, no global state).
  The host calls `layout/1` once per frame, then uses `body_block/1`
  and `footer/3` to build the chrome widgets.
  """

  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Widgets.{Block, Paragraph}

  # Code BEAM Europe magenta — the same accent lobby_tui uses (#e11fc1),
  # so every TUI in the talk shares one identity color. RGB rather than
  # named `:magenta`, which reads differently across terminal themes.
  @accent {:rgb, 225, 31, 193}
  @hints ["←/h prev", "→/l next", "n notes", "q quit"]
  @attribution "built with ex_ratatui"

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
  Footer widgets — a progress chip on the left, one chip per key hint
  in the middle, and an italic gray attribution on the right.

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
      [{:chip, " #{current_index + 1} / #{total} "}, :flex] ++
        Enum.intersperse(Enum.map(@hints, &{:chip, " #{&1} "}), {:gap, 1}) ++
        [{:gap, 2}, {:attr, " #{@attribution} "}]

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

  defp build_segment({{:attr, text}, rect}),
    do: [{%Paragraph{text: text, style: attribution_style(), alignment: :right}, rect}]

  defp chip_style, do: %Style{fg: :black, bg: @accent, modifiers: [:bold]}
  defp attribution_style, do: %Style{fg: :dark_gray, modifiers: [:italic]}
end
