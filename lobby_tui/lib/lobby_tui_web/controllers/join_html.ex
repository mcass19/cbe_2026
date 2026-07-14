defmodule LobbyTuiWeb.JoinHTML do
  use LobbyTuiWeb, :html

  embed_templates "join_html/*"

  @doc "Renders one avatar sprite as an HTML grid of colored half-block spans."
  def sprite(assigns) do
    ~H"""
    <span class="sprite" style="display:inline-block; line-height:1; font-family:monospace;">
      <span :for={row <- @cells} style="display:block;">
        <span
          :for={{char, fg, bg} <- row}
          style={cell_style(fg, bg)}
        >
          {char}
        </span>
      </span>
    </span>
    """
  end

  defp cell_style(fg, bg) do
    [fg && "color:#{css(fg)}", bg && "background-color:#{css(bg)}"]
    |> Enum.filter(& &1)
    |> Enum.join(";")
  end

  defp css({:rgb, r, g, b}), do: "rgb(#{r},#{g},#{b})"
end
