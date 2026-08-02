defmodule SlidesTui.Layout do
  @moduledoc """
  Layout helpers for slide authors.

  Slides live inside the body rect the host passes to `render/2`. For
  decks aimed at projectors or large terminals, parking content in the
  upper-left corner reads as off-balance — anchoring it in the middle
  almost always looks better. `center/2` returns a sub-rect of `area`
  shrunk to the requested width and/or height and centered along that
  axis, so a slide can hand it straight to a widget (or a
  `Layout.split/3` call) without doing the padding arithmetic itself.

  ## Examples

      # Centered band, full width
      rect = SlidesTui.Layout.center(area, height: 4)

      # Centered both ways for a bundle of widgets
      bundle = SlidesTui.Layout.center(area, width: 80, height: 20)
  """

  alias ExRatatui.Layout.Rect

  @typedoc """
  Options for `center/2`.

    * `:width` — clamp the result to this width and center horizontally.
      Omit to keep the full width of `area`.
    * `:height` — clamp the result to this height and center vertically.
      Omit to keep the full height of `area`.
  """
  @type opt :: {:width, non_neg_integer()} | {:height, non_neg_integer()}

  @doc """
  Returns a sub-rect of `area` centered on the constrained axes.

  Both `:width` and `:height` are clamped to `area`'s dimensions, so an
  oversized request simply uses all the space available on that axis.
  When an axis is unconstrained the result spans the full extent of
  `area` on that axis.
  """
  @spec center(Rect.t(), [opt()]) :: Rect.t()
  def center(%Rect{} = area, opts \\ []) do
    width = clamp(Keyword.get(opts, :width, area.width), area.width)
    height = clamp(Keyword.get(opts, :height, area.height), area.height)

    %Rect{
      x: area.x + div(area.width - width, 2),
      y: area.y + div(area.height - height, 2),
      width: width,
      height: height
    }
  end

  defp clamp(value, max) when is_integer(value) and value >= 0, do: min(value, max)
end
