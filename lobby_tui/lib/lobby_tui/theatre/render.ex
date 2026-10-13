defmodule LobbyTui.Theatre.Render do
  @moduledoc """
  Pure rendering: state plus frame in, `{widget, rect}` pairs out. The world is a Paragraph of styled spans cropped by a camera that follows the attendee. Per visible cell the compositor layers, back to front: the painted theatre scene, a reserved-chair wash for seats whose occupant is temporarily gone (the disconnect grace window — standing frees a seat immediately, so held-but-empty only means "reconnecting"), avatar sprites (others first, self last), and floating name labels (others first, self last) — see design doc section D3. Once seated the camera lifts to the stage and the feed plays there, between the parted curtains, rather than in a band of its own; until the feed has its first message, an `Ascii` marquee sign plays there instead. The last line is a one-row status strip that shows the current hint, if any, and is otherwise blank: the surrounding HTML has no written key legend (its buttons name their own actions), so this row is the only place situational guidance appears.
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

  # The drape covers the stage band below the apron — an apron does not
  # travel with the curtain, so it stays put. The opening grows outward
  # from the proscenium's centre line.
  @stage_curtain_rows (World.apron_rows().last + 1)..World.stage_rows().last
  @stage_center_x div(176, 2)

  # Widest half-opening: out to the wall trim on either side.
  @stage_max_half 84

  # Rows inside the opening reserved for the feed, newest last, with a row
  # of breathing space at each edge of the drape.
  @stage_text_rows (World.apron_rows().last + 2)..(World.stage_rows().last - 1)

  @stage_interior {:rgb, 16, 10, 22}
  @stage_author {:rgb, 34, 206, 222}
  @stage_body {:rgb, 233, 233, 240}

  @doc """
  How many feed lines the stage shows at once. `Theatre` reads this to
  clamp the seated scroll offset without restating the stage geometry.
  """
  def stage_line_count, do: Range.size(@stage_text_rows)

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

  # The chair core inside a seat footprint: the scene painter leaves one
  # column of floor on each side of the footprint, so the wash covers
  # exactly the painted chair and nothing else.
  {footprint_dx, footprint_dy} = World.footprint_offsets()
  @held_dx (footprint_dx.first + 1)..(footprint_dx.last - 1)
  @held_dy footprint_dy
  @held_margin_x max(abs(@held_dx.first), abs(@held_dx.last))
  @held_margin_y max(abs(@held_dy.first), abs(@held_dy.last))

  # The occupant color's share when washing a held chair's own pixels —
  # a subtle wash, enough to read as "taken" without shouting.
  @held_mix 0.35

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
    {x_range, y_range, overlay} = compose(state, vw, vh)
    for y <- y_range, do: cell_line(overlay, x_range, y)
  end

  defp compose(state, vw, vh) do
    {ox, oy} = viewport_origin(state, vw, vh)
    x_range = ox..(ox + min(vw, World.width()) - 1)
    y_range = oy..(oy + min(vh, World.height()) - 1)
    {x_range, y_range, build_overlay(state, x_range, y_range)}
  end

  defp cell_line(overlay, x_range, y),
    do: %Line{spans: for(x <- x_range, do: Map.get(overlay, {x, y}) || scene_span({x, y}))}

  @doc """
  Where the viewport sits in the world.

  Standing, it follows the attendee. Seated, it drops to the stage and
  stays there: the curtain is about to go up and the attendee is meant to
  be watching it, not themselves. The stage sits along the bottom of the
  world, so anchoring at the last row frames it with the front rows of the
  house above, and the room still reads as occupied.
  """
  def viewport_origin(%State{seated?: true}, vw, vh) do
    max_ox = max(World.width() - vw, 0)
    max_oy = max(World.height() - vh, 0)
    {(@stage_center_x - div(vw, 2)) |> max(0) |> min(max_ox), max_oy}
  end

  def viewport_origin(%State{pos: pos}, vw, vh), do: camera(pos, vw, vh)

  def camera({px, py}, vw, vh) do
    max_ox = max(World.width() - vw, 0)
    max_oy = max(World.height() - vh, 0)
    ox = (px - div(vw, 2)) |> max(0) |> min(max_ox)
    oy = (py - div(vh, 2)) |> max(0) |> min(max_oy)
    {ox, oy}
  end

  # The drawn frame carries one span per run of same-styled cells instead of
  # one per cell. It looks the same, but encoding spans through the NIF is
  # most of a draw's cost, and a 120×40 room is 4,680 cells. `world_lines/3`
  # keeps one span per cell, so tests can still address a single cell.
  #
  # Building and merging those spans was most of `render/2`'s own cost, and
  # most rows have nobody on them: those come merged from `Scene`'s row
  # cache, and only rows with something drawn over the scene are built.
  defp cropped_lines(state, vw, vh) do
    {x_range, y_range, overlay} = compose(state, vw, vh)
    drawn_rows = for {{_x, y}, _span} <- overlay, into: MapSet.new(), do: y

    for y <- y_range do
      if MapSet.member?(drawn_rows, y) do
        overlay |> cell_line(x_range, y) |> merge_runs()
      else
        Scene.row({y, x_range}, fn -> %{} |> cell_line(x_range, y) |> merge_runs() end)
      end
    end
  end

  defp merge_runs(%Line{spans: spans} = line) do
    merged =
      spans
      |> Enum.chunk_by(& &1.style)
      |> Enum.map(fn [first | _] = run ->
        %{first | content: Enum.map_join(run, & &1.content)}
      end)

    %{line | spans: merged}
  end

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
    |> paint_stage_marquee(state, x_range, y_range)
    |> paint_stage_feed(state, cols, x_range, y_range)
  end

  # The "now showing" sign, centred in the opening, for as long as the
  # stage is open with nothing on it. `Theatre` stops the sign a tick after
  # either changes, so the guard keeps a stale frame off a feed or a
  # closing drape in the meantime. Spaces are skipped: the opening behind
  # is already the stage interior.
  defp paint_stage_marquee(
         overlay,
         %State{feed: [], marquee_frame: %Ascii.Frame{} = frame, curtain: curtain},
         x_range,
         y_range
       ) do
    if curtain == LobbyTui.Theatre.curtain_steps() do
      left = @stage_center_x - div(frame.cols, 2)
      top = @stage_curtain_rows.first + div(Range.size(@stage_curtain_rows) - frame.rows, 2)

      for {line, dy} <- frame |> Ascii.ExRatatui.lines(ground: false) |> Enum.with_index(),
          {{char, fg}, dx} <- line |> marquee_cells() |> Enum.with_index(),
          char != " ",
          pos = {left + dx, top + dy},
          in_ranges?(pos, x_range, y_range),
          into: overlay do
        {pos, %Span{content: char, style: %Style{fg: fg || @stage_body, bg: @stage_interior}}}
      end
    else
      overlay
    end
  end

  defp paint_stage_marquee(overlay, _state, _x_range, _y_range), do: overlay

  # `lines/2` gives a span per run of one colour; the overlay wants a cell.
  defp marquee_cells(%Line{spans: spans}) do
    for span <- spans, char <- String.graphemes(span.content), do: {char, span.style.fg}
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
      # stage reads like a transcript rather than a stack. `feed_scroll`
      # skips that many of the newest messages, leafing back in history.
      shown =
        feed
        |> Enum.drop(state.feed_scroll)
        |> Enum.take(length(rows))
        |> Enum.reverse()

      shown
      |> Enum.zip(Enum.take(rows, -length(shown)))
      |> Enum.reduce(overlay, fn {msg, row}, ovl ->
        paint_stage_line(ovl, msg, row, cols, state.avatar_cache, x_range, y_range)
      end)
    end
  end

  defp paint_stage_line(overlay, msg, row, cols, avatar_cache, x_range, y_range) do
    if row in y_range do
      author = "#{msg.author_nickname}: "

      spans =
        styled_graphemes(author, author_color(msg, avatar_cache)) ++
          styled_graphemes(msg.body, @stage_body)

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

  # The author's nickname plays in their avatar's dominant color, tying
  # the line on stage to the sprite in the house. Messages without a
  # resolvable avatar (author long gone in a fixture, cache miss) keep the
  # neutral stage color.
  defp author_color(msg, avatar_cache) do
    case sprite_entry(Map.get(msg, :author_avatar_id), avatar_cache) do
      %{color: {:rgb, _, _, _} = color} -> color
      _no_entry -> @stage_author
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

  # -- reserved-chair wash --------------------------------------------------

  # `state.occupied` is bounded by the fixed seat count (80, a world
  # constant — never grows with attendee population), and is further
  # filtered to the viewport before any work happens. The anchor filter
  # uses the wash's own margins so a chair straddling the viewport edge
  # still paints its visible cells.
  defp paint_tints(overlay, %State{} = state, x_range, y_range) do
    hx_range = expand(x_range, @held_margin_x)
    hy_range = expand(y_range, @held_margin_y)

    state.occupied
    |> Enum.filter(fn {pos, _occupant} -> in_ranges?(pos, hx_range, hy_range) end)
    |> Enum.reject(fn {pos, _occupant} -> anchored?(state, pos) end)
    |> Enum.reduce(overlay, fn {pos, %{color: color}}, ovl ->
      paint_held_seat(ovl, pos, color, x_range, y_range)
    end)
  end

  # A held seat means its occupant is inside the disconnect grace window:
  # standing or leaving frees a seat immediately, so the only way a claimed
  # chair sits empty is an occupant who may be about to come back. The
  # chair keeps its own pixel art but washed toward the occupant's color,
  # so "taken, they're reconnecting" reads at a glance.
  defp paint_held_seat(overlay, {ax, ay} = pos, {:rgb, _r, _g, _b} = color, x_range, y_range) do
    if Scene.loaded?() do
      for dx <- @held_dx,
          dy <- @held_dy,
          cell_pos = {ax + dx, ay + dy},
          in_ranges?(cell_pos, x_range, y_range),
          scene_cell = Scene.cell(cell_pos),
          scene_cell != nil,
          reduce: overlay do
        ovl ->
          {char, fg, bg} = scene_cell

          Map.put(ovl, cell_pos, %Span{
            content: char,
            style: %Style{fg: wash(fg, color), bg: wash(bg, color)}
          })
      end
    else
      paint_held_marker(overlay, pos, color, x_range, y_range)
    end
  end

  # Occupant colors are `{:rgb, _, _, _}` in practice (the avatar's
  # dominant color, fetched at claim time); a named-atom color is the
  # presence-miss fallback and cannot be blended, so it keeps the compact
  # marker. Same for a missing scene: there is no chair to wash.
  defp paint_held_seat(overlay, pos, color, x_range, y_range) do
    paint_held_marker(overlay, pos, color, x_range, y_range)
  end

  defp paint_held_marker(overlay, pos, color, x_range, y_range) do
    if in_ranges?(pos, x_range, y_range) do
      Map.put(overlay, pos, %Span{content: @occupancy_marker, style: %Style{fg: color}})
    else
      overlay
    end
  end

  defp wash({:rgb, r, g, b}, {:rgb, tr, tg, tb}) do
    {:rgb, mix(r, tr), mix(g, tg), mix(b, tb)}
  end

  # A scene cell's fg/bg is always rgb today; anything else passes through
  # unwashed rather than guessing at a blend.
  defp wash(other, _color), do: other

  defp mix(base, tint), do: round(base * (1 - @held_mix) + tint * @held_mix)

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
