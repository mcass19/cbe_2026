defmodule SlidesTui.NotesPopup do
  @moduledoc """
  Pure overlay builder for the speaker-notes popup.

  Renders three widgets stacked at the same centered rect: a `Clear`
  to wipe whatever the slide drew underneath, a `Block` to frame the
  popup with a titled border and fill it with the theme's chip colours,
  and a `Markdown` widget inside the block to render the notes content.

  The popup occupies ~70% of the frame width and ~60% of the frame
  height, centered.
  """

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Widgets.{Block, Clear, Markdown}
  alias SlidesTui.Theme

  @width_pct 70
  @height_pct 60

  @doc """
  Returns `[{Clear, popup_rect}, {Block, popup_rect}, {Markdown, inner_rect}]`
  centered within `frame_area`.
  """
  @spec overlay(String.t(), Rect.t(), Theme.t()) :: [{struct(), Rect.t()}]
  def overlay(notes_markdown, %Rect{} = frame_area, theme \\ Theme.fetch!(Theme.default()))
      when is_binary(notes_markdown) do
    popup = popup_rect(frame_area)
    inner = inner_rect(popup)

    # Clear resets the cells to the terminal's own colours, so the
    # block repaints the popup in the theme right after it.
    [
      {%Clear{}, popup},
      {%Block{
         title: " Notes ",
         borders: [:all],
         border_style: %Style{fg: theme.accent},
         style: %Style{fg: theme.chip_fg, bg: theme.chip_bg}
       }, popup},
      {%Markdown{content: notes_markdown}, inner}
    ]
  end

  defp popup_rect(%Rect{x: x, y: y, width: w, height: h}) do
    pw = div(w * @width_pct, 100)
    ph = div(h * @height_pct, 100)

    %Rect{
      x: x + div(w - pw, 2),
      y: y + div(h - ph, 2),
      width: pw,
      height: ph
    }
  end

  defp inner_rect(%Rect{x: x, y: y, width: w, height: h}) do
    %Rect{x: x + 1, y: y + 1, width: max(w - 2, 0), height: max(h - 2, 0)}
  end
end
