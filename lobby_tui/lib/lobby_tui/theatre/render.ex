defmodule LobbyTui.Theatre.Render do
  @moduledoc """
  Pure rendering: state plus frame in, `{widget, rect}` pairs out. The world is a Paragraph of styled spans cropped by a camera that follows the attendee. Per visible cell the compositor layers, back to front: the painted theatre scene, an occupied-seat tint for seats whose occupant is not currently visible, avatar sprites (others first, self last), and floating name labels (others first, self last) — see design doc section D3. The stage feed takes the bottom band once seated; the last line is a one-row status strip that shows the current hint, if any, and is otherwise blank — the HTML `#key-bar` chrome around the embed already carries the always-on move/sit/stand help.
  """

  alias ExRatatui.Frame
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Text
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.Paragraph
  alias LobbyTui.Scene
  alias LobbyTui.Theatre.State
  alias LobbyTui.World

  @feed_height 8
  @status_height 1

  # Off-scene / not-yet-loaded fallback: a plain dark floor cell.
  @floor_span %Span{content: " ", style: %Style{bg: :black}}

  # Search margins around the base viewport when hunting for attendee
  # anchors whose sprite/label rectangle might intersect it. These mirror
  # the world's standard sprite envelope (D1): 12 cols wide (up to 6 either
  # side of the anchor) and 6 sprite rows plus 1 label row above the
  # anchor. A cache entry with a smaller fixture sprite (as tests inject)
  # just means some of the scanned candidates never hit — still correct,
  # only a little more scanning than strictly necessary.
  @sprite_margin_x 6
  @sprite_margin_y 7

  # Fixed world-grid offset of the name label above an anchor (D1's
  # pitch: 6 sprite rows + 1 label row) — not derived from the sprite's
  # actual height, since the label row is a layout constant, not a
  # per-avatar one.
  @label_offset 6

  @occupancy_marker "▪"

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
    x_range = ox..(ox + min(vw, World.width()) - 1)
    y_range = oy..(oy + min(vh, World.height()) - 1)
    overlay = build_overlay(state, x_range, y_range)

    for y <- y_range do
      %Line{spans: for(x <- x_range, do: Map.get(overlay, {x, y}) || scene_span({x, y}))}
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

  # -- compositor --------------------------------------------------------

  # Order matters: tint first (so a real sprite anchored on the seat
  # naturally paints over it), then sprites (others, self last), then
  # labels (others, self last) — self always wins overlaps.
  defp build_overlay(%State{} = state, x_range, y_range) do
    ax_range = expand(x_range, @sprite_margin_x)
    ay_range = expand(y_range, @sprite_margin_y)

    overlay = paint_tints(%{}, state, x_range, y_range)

    {overlay, others_found} =
      paint_others_sprites(overlay, state, ax_range, ay_range, x_range, y_range)

    overlay = paint_self_sprite(overlay, state, x_range, y_range)
    overlay = paint_other_labels(overlay, others_found, x_range, y_range)
    paint_self_label(overlay, state, x_range, y_range)
  end

  # Scans the (viewport-bound, not population-bound) expanded anchor box
  # for entries present in `others_by_pos` — an O(1) map lookup per
  # candidate cell, never a full scan of the attendee population.
  defp paint_others_sprites(overlay, %State{} = state, ax_range, ay_range, x_range, y_range) do
    Enum.reduce(ay_range, {overlay, []}, fn y, acc ->
      Enum.reduce(ax_range, acc, fn x, {ovl, found} ->
        case Map.fetch(state.others_by_pos, {x, y}) do
          {:ok, other} ->
            entry = sprite_entry(other.avatar_id, state.avatar_cache)
            ovl = paint_anchor(ovl, entry, {x, y}, other.color, x_range, y_range, :other)
            {ovl, [{other, {x, y}, entry} | found]}

          :error ->
            {ovl, found}
        end
      end)
    end)
  end

  defp paint_self_sprite(overlay, %State{} = state, x_range, y_range) do
    entry = sprite_entry(state.attendee.avatar_id, state.avatar_cache)
    paint_anchor(overlay, entry, state.pos, state.color, x_range, y_range, :self)
  end

  defp sprite_entry(nil, _avatar_cache), do: nil

  defp sprite_entry(avatar_id, avatar_cache),
    do: Map.get(avatar_cache, avatar_id) || Map.get(avatar_cache, :fallback)

  # No cache entry at all (own avatar missing AND the built-in fallback
  # missing) — should only happen in a deliberately broken test fixture,
  # never in production (SpriteLoader always seeds `unknown`).
  defp paint_anchor(overlay, nil, pos, color, x_range, y_range, who) do
    if in_ranges?(pos, x_range, y_range) do
      char = if who == :self, do: "@", else: "☻"
      modifiers = if who == :self, do: [:bold], else: []

      Map.put(overlay, pos, %Span{
        content: char,
        style: %Style{fg: color || :white, modifiers: modifiers}
      })
    else
      overlay
    end
  end

  defp paint_anchor(overlay, %{cells: cells}, pos, _color, x_range, y_range, _who) do
    paint_sprite_cells(overlay, cells, pos, x_range, y_range)
  end

  defp paint_sprite_cells(overlay, [], _anchor, _x_range, _y_range), do: overlay

  defp paint_sprite_cells(overlay, [first_row | _] = cells, {x, y}, x_range, y_range) do
    height = length(cells)
    width = length(first_row)
    left = x - div(width - 1, 2)
    top = y - (height - 1)

    cells
    |> Enum.with_index()
    |> Enum.reduce(overlay, fn {row, ry}, ovl ->
      paint_sprite_row(ovl, row, left, top + ry, x_range, y_range)
    end)
  end

  defp paint_sprite_row(overlay, row, left, cell_y, x_range, y_range) do
    if cell_y in y_range do
      row
      |> Enum.with_index()
      |> Enum.reduce(overlay, fn {cell, rx}, ovl ->
        paint_sprite_cell(ovl, {left + rx, cell_y}, cell, (left + rx) in x_range)
      end)
    else
      overlay
    end
  end

  defp paint_sprite_cell(overlay, _pos, {" ", nil, nil}, _in_range?), do: overlay
  defp paint_sprite_cell(overlay, _pos, _cell, false), do: overlay

  defp paint_sprite_cell(overlay, pos, {char, fg, bg}, true),
    do: Map.put(overlay, pos, %Span{content: char, style: %Style{fg: fg, bg: bg}})

  # -- labels --------------------------------------------------------

  defp paint_other_labels(overlay, found, x_range, y_range) do
    Enum.reduce(found, overlay, fn {other, pos, entry}, ovl ->
      paint_label(ovl, other.nickname, pos, other.color, false, x_range, y_range, entry)
    end)
  end

  defp paint_self_label(overlay, %State{} = state, x_range, y_range) do
    entry = sprite_entry(state.attendee.avatar_id, state.avatar_cache)

    paint_label(
      overlay,
      state.attendee.nickname,
      state.pos,
      state.color,
      true,
      x_range,
      y_range,
      entry
    )
  end

  defp paint_label(overlay, nickname, {x, _y} = pos, color, self?, x_range, y_range, entry) do
    row = label_row(pos, entry)

    if row in y_range do
      chars = String.graphemes(nickname)
      start_x = label_start(x, length(chars))
      style = label_style(color, self?)

      chars
      |> Enum.with_index()
      |> Enum.reduce(overlay, fn {char, i}, ovl ->
        cx = start_x + i

        if cx in x_range,
          do: Map.put(ovl, {cx, row}, %Span{content: char, style: style}),
          else: ovl
      end)
    else
      overlay
    end
  end

  # No cache entry at all: the anchor paints as a 1-cell marker sitting
  # directly on `pos` (see `paint_anchor/7`'s nil-entry clause), so the
  # label goes directly above that single cell, not the sprite pitch.
  defp label_row({_x, y}, nil), do: y - 1

  # `top_trim` (the avatar cache's precomputed count of leading fully
  # transparent sprite rows, see `LobbyTui.Theatre.build_avatar_cache/0`)
  # hugs the label to the sprite's visible pixels. Clamped to `y - 1` so a
  # degenerate (fully transparent) sprite never pushes the label below the
  # anchor's own row.
  defp label_row({_x, y}, entry) do
    min(y - @label_offset + Map.get(entry, :top_trim, 0), y - 1)
  end

  defp label_start(x, len) do
    (x - div(len, 2)) |> max(0) |> min(max(World.width() - len, 0))
  end

  defp label_style(color, true), do: %Style{fg: color, modifiers: [:bold]}
  defp label_style(color, false), do: %Style{fg: color}

  # -- occupied-seat tint --------------------------------------------------

  # `state.occupied` is bounded by the fixed seat count (120, a world
  # constant — never grows with attendee population), and is further
  # filtered to the viewport before any work happens.
  defp paint_tints(overlay, %State{} = state, x_range, y_range) do
    state.occupied
    |> Enum.filter(fn {pos, _occupant} -> in_ranges?(pos, x_range, y_range) end)
    |> Enum.reject(fn {pos, _occupant} -> anchored?(state, pos) end)
    |> Enum.reduce(overlay, fn {pos, %{color: color}}, ovl ->
      Map.put(ovl, pos, %Span{content: @occupancy_marker, style: %Style{fg: color}})
    end)
  end

  defp anchored?(%State{pos: pos}, seat_pos) when pos == seat_pos, do: true
  defp anchored?(%State{others_by_pos: others}, seat_pos), do: Map.has_key?(others, seat_pos)

  # -- scene ---------------------------------------------------------------

  defp scene_span(pos) do
    case Scene.cell(pos) do
      nil -> @floor_span
      {char, fg, bg} -> %Span{content: char, style: %Style{fg: fg, bg: bg}}
    end
  end

  # -- shared helpers -------------------------------------------------------

  defp expand(range, margin), do: (range.first - margin)..(range.last + margin)

  defp in_ranges?({x, y}, x_range, y_range), do: x in x_range and y in y_range

  # -- feed / status --------------------------------------------------------

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

  # Hints only — the always-on unseated/seated help text used to live here
  # too, but it duplicated the HTML `#key-bar` (owner screenshot feedback).
  # The row itself stays even with no hint, empty, for layout stability:
  # hints must not shift the world.
  defp status_paragraph(%State{hint: hint}) do
    %Paragraph{text: hint || "", style: %Style{fg: :dark_gray}}
  end
end
