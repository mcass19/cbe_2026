defmodule LobbyTui.Theatre.Render do
  @moduledoc """
  Pure rendering: state plus frame in, `{widget, rect}` pairs out. The world is a Paragraph of styled spans cropped by a camera that follows the attendee; the stage feed takes the bottom band once seated; the last line is a one-row status strip (hint or seated/unseated help text).
  """

  alias ExRatatui.Frame
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Text
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias LobbyTui.Theatre.State
  alias LobbyTui.World

  @feed_height 8
  @status_height 1

  @wall %Span{content: "█", style: %Style{fg: :dark_gray}}
  @stage %Span{content: "░", style: %Style{fg: :yellow}}
  @floor %Span{content: " ", style: %Style{}}
  @seat_free %Span{content: "▪", style: %Style{fg: :green}}
  @seat_taken %Span{content: "▪", style: %Style{fg: :red}}

  def widgets(%State{} = state, %Frame{width: fw, height: fh}) do
    feed_h = if state.seated?, do: min(@feed_height, max(fh - @status_height - 5, 0)), else: 0
    world_h = max(fh - feed_h - @status_height, 1)

    world = {world_paragraph(state, fw, world_h), %Rect{x: 0, y: 0, width: fw, height: world_h}}
    status = {status_paragraph(state), %Rect{x: 0, y: fh - 1, width: fw, height: @status_height}}

    if feed_h > 0 do
      feed = {feed_paragraph(state, feed_h), %Rect{x: 0, y: world_h, width: fw, height: feed_h}}
      [world, feed, status]
    else
      [world, status]
    end
  end

  def world_paragraph(state, vw, vh) do
    %Paragraph{text: %Text{lines: cropped_lines(state, vw, vh)}}
  end

  def world_lines(state, vw, vh) do
    {ox, oy} = camera(state.pos, vw, vh)

    for y <- oy..(oy + min(vh, World.height()) - 1) do
      %Line{spans: for(x <- ox..(ox + min(vw, World.width()) - 1), do: cell_span(state, {x, y}))}
    end
  end

  def camera({px, py}, vw, vh) do
    max_ox = max(World.width() - vw, 0)
    max_oy = max(World.height() - vh, 0)
    ox = (px - div(vw, 2)) |> max(0) |> min(max_ox)
    oy = (py - div(vh, 2)) |> max(0) |> min(max_oy)
    {ox, oy}
  end

  defp cropped_lines(state, vw, vh), do: world_lines(state, vw, vh)

  defp cell_span(%State{pos: pos, color: color}, cell) when pos == cell,
    do: %Span{content: "@", style: %Style{fg: color, modifiers: [:bold]}}

  defp cell_span(%State{} = state, {x, y} = cell) do
    case Enum.find(state.others, fn {_id, o} -> o.x == x and o.y == y end) do
      {_id, other} ->
        %Span{content: "☻", style: %Style{fg: other.color || :white}}

      nil ->
        case World.tile_at(cell) do
          :wall -> @wall
          :stage -> @stage
          :floor -> @floor
          :seat -> if Map.has_key?(state.occupied, cell), do: @seat_taken, else: @seat_free
        end
    end
  end

  defp feed_paragraph(%State{feed: feed}, feed_h) do
    lines =
      feed
      |> Enum.take(feed_h - 1)
      |> Enum.reverse()
      |> Enum.map(fn msg ->
        %Line{
          spans: [
            %Span{
              content: "#{msg.author_nickname}: ",
              style: %Style{fg: :cyan, modifiers: [:bold]}
            },
            %Span{content: msg.body, style: %Style{}}
          ]
        }
      end)

    header = %Line{spans: [%Span{content: "── stage ──", style: %Style{fg: :yellow}}]}
    %Paragraph{text: %Text{lines: [header | lines]}}
  end

  defp status_paragraph(%State{hint: hint} = state) do
    text =
      cond do
        hint -> hint
        state.seated? -> "seated — type below to post"
        true -> "arrows to move · walk onto a seat and press sit"
      end

    %Paragraph{text: text, style: %Style{fg: :dark_gray}}
  end
end
