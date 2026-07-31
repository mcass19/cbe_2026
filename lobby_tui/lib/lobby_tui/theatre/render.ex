defmodule LobbyTui.Theatre.Render do
  @moduledoc """
  Pure rendering: state plus frame in, `{widget, rect}` pairs out. The world is a Paragraph of styled spans cropped by a camera that follows the attendee. Per visible cell the compositor layers, back to front: the painted theatre scene, an occupied-seat tint for seats whose occupant is not currently visible, avatar sprites (others first, self last), and floating name labels (others first, self last) — see design doc section D3. Once seated the camera lifts to the stage and the feed plays there, between the parted curtains, rather than in a band of its own. The last line is a one-row status strip that shows the current hint, if any, and is otherwise blank: the surrounding HTML has no written key legend (its buttons name their own actions), so this row is the only place situational guidance appears.
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

  @status_height 1

  # -- stage ---------------------------------------------------------------

  # The curtain rows of the painted stage band (rows 12..13 are the apron
  # and stay put — an apron does not travel with the drape). The opening
  # grows outward from the proscenium's centre line, which the scene's own
  # symmetry axis puts at column 88.
  @stage_curtain_rows 2..11
  @stage_center_x 88

  # Widest half-opening: out to the wall trim on either side.
  @stage_max_half 84

  # Rows inside the opening reserved for the feed, newest last, leaving
  # the top row of the opening as breathing space under the pelmet.
  @stage_text_rows 4..11

  @stage_interior {:rgb, 16, 10, 22}
  @stage_author {:rgb, 34, 206, 222}
  @stage_body {:rgb, 233, 233, 240}

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

  # The feed used to take a band at the bottom of the frame. It now plays
  # on the stage itself, inside the world, so the world owns everything
  # above the status row whether seated or not — one less layout mode, and
  # the room never resizes underneath the attendee when they sit.
  def widgets(%State{} = state, %Frame{width: fw, height: fh}) do
    world_h = max(fh - @status_height, 1)

    world = {world_paragraph(state, fw, world_h), %Rect{x: 0, y: 0, width: fw, height: world_h}}
    status = {status_paragraph(state), %Rect{x: 0, y: fh - 1, width: fw, height: @status_height}}

    [world, status]
  end

  def world_paragraph(state, vw, vh) do
    %Paragraph{text: %Text{lines: cropped_lines(state, vw, vh)}}
  end

  def world_lines(state, vw, vh) do
    {ox, oy} = viewport_origin(state, vw, vh)
    x_range = ox..(ox + min(vw, World.width()) - 1)
    y_range = oy..(oy + min(vh, World.height()) - 1)
    overlay = build_overlay(state, x_range, y_range)

    for y <- y_range do
      %Line{spans: for(x <- x_range, do: Map.get(overlay, {x, y}) || scene_span({x, y}))}
    end
  end

  @doc """
  Where the viewport sits in the world.

  Standing, it follows the attendee. Seated, it lifts to the stage and
  stays there: the curtain is about to go up and the attendee is meant to
  be watching it, not themselves. Anchoring at the top row also keeps the
  front rows of the house in shot below the stage, so the room still
  reads as occupied.
  """
  def viewport_origin(%State{seated?: true}, vw, _vh) do
    max_ox = max(World.width() - vw, 0)
    {(@stage_center_x - div(vw, 2)) |> max(0) |> min(max_ox), 0}
  end

  def viewport_origin(%State{pos: pos}, vw, vh), do: camera(pos, vw, vh)

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
    overlay = paint_self_label(overlay, state, x_range, y_range)
    paint_stage(overlay, state, x_range, y_range)
  end

  # -- stage ---------------------------------------------------------------

  # Painted last so the stage band is unambiguously the stage's: nothing
  # walks up there (rows 2..13 are not walkable), but a tall sprite or a
  # long label anchored in the front row could otherwise reach into it.
  defp paint_stage(overlay, %State{curtain: 0}, _x_range, _y_range), do: overlay

  defp paint_stage(overlay, %State{} = state, x_range, y_range) do
    cols = opening_cols(state.curtain)

    overlay
    |> open_curtain(cols, x_range, y_range)
    |> paint_stage_feed(state, cols, x_range, y_range)
  end

  # The drape parts symmetrically about the centre line, so the opening is
  # always an even-handed slice of the band.
  defp opening_cols(curtain) do
    half = div(curtain * @stage_max_half, LobbyTui.Theatre.curtain_steps())
    (@stage_center_x - half)..(@stage_center_x + half)
  end

  defp open_curtain(overlay, cols, x_range, y_range) do
    for y <- @stage_curtain_rows,
        y in y_range,
        x <- cols,
        x in x_range,
        into: overlay do
      {{x, y}, %Span{content: " ", style: %Style{bg: @stage_interior}}}
    end
  end

  # Held back until the curtain is all the way open — text creeping out
  # from behind a moving drape reads as a glitch, not a reveal.
  defp paint_stage_feed(overlay, %State{feed: feed} = state, cols, x_range, y_range) do
    if state.curtain < LobbyTui.Theatre.curtain_steps() do
      overlay
    else
      rows = Enum.to_list(@stage_text_rows)
      # `feed` is newest-first; show the newest on the bottom line so the
      # stage reads like a transcript rather than a stack.
      shown = feed |> Enum.take(length(rows)) |> Enum.reverse()

      shown
      |> Enum.zip(Enum.take(rows, -length(shown)))
      |> Enum.reduce(overlay, fn {msg, row}, ovl ->
        paint_stage_line(ovl, msg, row, cols, x_range, y_range)
      end)
    end
  end

  defp paint_stage_line(overlay, msg, row, cols, x_range, y_range) do
    if row in y_range do
      author = "#{msg.author_nickname}: "
      spans = styled_graphemes(author, @stage_author) ++ styled_graphemes(msg.body, @stage_body)
      spans = Enum.take(spans, Range.size(cols))
      start_x = cols.first + div(Range.size(cols) - length(spans), 2)

      spans
      |> Enum.with_index()
      |> Enum.reduce(overlay, fn {span, i}, ovl ->
        x = start_x + i
        if x in x_range, do: Map.put(ovl, {x, row}, span), else: ovl
      end)
    else
      overlay
    end
  end

  defp styled_graphemes(text, fg) do
    for char <- String.graphemes(text) do
      %Span{content: char, style: %Style{fg: fg, bg: @stage_interior}}
    end
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

  # -- status ---------------------------------------------------------------

  # Hints only. An always-on "arrows to move, s to sit" legend used to live
  # here and again in the HTML around the embed; both are gone, because the
  # on-screen pad's buttons already name every action they perform. What is
  # left is the situational half — "seat taken", "press space to stand" —
  # which only this row knows. It stays even when empty, for layout
  # stability: a hint appearing must never shift the world.
  defp status_paragraph(%State{hint: hint}) do
    %Paragraph{text: hint || "", style: %Style{fg: :dark_gray}}
  end
end
