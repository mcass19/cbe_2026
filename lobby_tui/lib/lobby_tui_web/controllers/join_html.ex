defmodule LobbyTuiWeb.JoinHTML do
  use LobbyTuiWeb, :html

  embed_templates "join_html/*"

  # `mix format`'s HEEx formatter re-wraps `~H` templates onto multiple
  # lines for readability, and HEEx (unlike plain HTML) renders that
  # reflowed source whitespace as literal text nodes — that is exactly how
  # this markup used to break: `{char}` alone on its own line meant real
  # whitespace around it in the DOM, and default CSS whitespace collapsing
  # turned that into a visible extra space per cell, doubling the sprite's
  # apparent width. Building the whole element as a plain string in
  # `sprite_html/1`, outside any `~H` block, keeps the formatter from ever
  # reflowing it, so "no whitespace between cells" holds no matter how this
  # file gets reformatted.
  #
  # `<.sprite .../>` is invoked from a caller's `~H` template, though, and
  # `Phoenix.LiveView.TagEngine.component/3` requires the callee to return
  # a `%Phoenix.LiveView.Rendered{}` — a bare `Phoenix.HTML.raw/1` value
  # does not satisfy that — so a trivial `~H` wrapper is still needed here.
  # Its template is nothing but `{@raw}`, so the only whitespace the
  # formatter can add sits outside the sprite's own `white-space:pre` span,
  # where default whitespace collapsing trims it away harmlessly.
  @doc "Renders one avatar sprite as an HTML grid of colored half-block spans."
  def sprite(assigns) do
    assigns = assign(assigns, :raw, sprite_html(assigns.cells))

    ~H"""
    {@raw}
    """
  end

  defp sprite_html(cells) do
    Phoenix.HTML.raw(
      ~s(<span class="sprite" style="display:inline-block; line-height:1; font-family:monospace; white-space:pre;">) <>
        rows_html(cells) <> "</span>"
    )
  end

  defp rows_html(cells), do: Enum.map_join(cells, &row_html/1)

  defp row_html(row) do
    ~s(<span style="display:block; white-space:pre;">) <>
      Enum.map_join(row, &cell_html/1) <> "</span>"
  end

  defp cell_html({char, fg, bg}) do
    ~s(<span style="#{cell_style(fg, bg)}">) <>
      Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(char)) <> "</span>"
  end

  defp cell_style(fg, bg) do
    [fg && "color:#{css(fg)}", bg && "background-color:#{css(bg)}"]
    |> Enum.filter(& &1)
    |> Enum.join(";")
  end

  defp css({:rgb, r, g, b}), do: "rgb(#{r},#{g},#{b})"
end
