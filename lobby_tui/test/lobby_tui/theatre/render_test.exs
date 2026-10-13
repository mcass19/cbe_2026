defmodule LobbyTui.Theatre.RenderTest do
  # Scene is a single global `:persistent_term` slot; the setup below stubs
  # it to empty for deterministic assertions and restores the real boot
  # value on exit, so this file cannot run concurrently with anything else
  # touching Scene.
  use ExUnit.Case, async: false

  alias ExRatatui.Frame
  alias ExRatatui.Style
  alias ExRatatui.Text.Span
  alias LobbyTui.Scene
  alias LobbyTui.Theatre.{Render, State}
  alias LobbyTui.World

  # 2 cols x 2 rows: opaque top-left, transparent top-right, opaque bottom
  # row (bottom-left is the anchor cell itself). Deliberately not 12x6 —
  # the compositor must not assume the standard sprite size.
  @fixture_sprite [
    [{"█", :cyan, nil}, {" ", nil, nil}],
    [{"█", :cyan, nil}, {"█", :cyan, nil}]
  ]

  @avatar_cache %{"av" => %{cells: @fixture_sprite, color: {:rgb, 9, 9, 9}}}

  setup do
    original = Scene.cells_snapshot()
    Scene.put_cells(%{})
    on_exit(fn -> Scene.put_cells(original) end)
    :ok
  end

  defp put_scene(cells), do: Scene.put_cells(cells)

  defp state(pos \\ World.spawn_point()) do
    attendee = %LobbyTui.Lobby.Attendee{id: "self", nickname: "me", avatar_id: "av"}
    %{State.new(attendee, {:rgb, 9, 9, 9}, @avatar_cache) | pos: pos}
  end

  defp cell(lines, x, y), do: lines |> Enum.at(y) |> Map.fetch!(:spans) |> Enum.at(x)

  # Mirrors Render's wash: 35% occupant color over the scene's own pixel.
  defp washed({:rgb, r, g, b}, {:rgb, tr, tg, tb}) do
    {:rgb, round(r * 0.65 + tr * 0.35), round(g * 0.65 + tg * 0.35), round(b * 0.65 + tb * 0.35)}
  end

  test "camera clamps to world bounds" do
    # viewport 80x40 inside a 176x96 world; max_ox = 176 - 80 = 96, max_oy = 96 - 40 = 56
    # near top-left corner: ox = 5 - div(80, 2) = 5 - 40 = -35 -> clamped to 0
    #                       oy = 5 - div(40, 2) = 5 - 20 = -15 -> clamped to 0
    assert Render.camera({5, 5}, 80, 40) == {0, 0}
    # near bottom-right corner: ox = 170 - 40 = 130 -> clamped to max_ox 96
    #                           oy = 90 - 20 = 70 -> clamped to max_oy 56
    assert Render.camera({170, 90}, 80, 40) == {96, 56}
    # centered, no clamping needed: ox = 90 - 40 = 50 (in 0..96); oy = 50 - 20 = 30 (in 0..56)
    assert Render.camera({90, 50}, 80, 40) == {50, 30}
  end

  test "camera centered on a full-world viewport is the origin" do
    # viewport equals world size (176x96); max_ox = max_oy = 0 regardless of pos
    assert Render.camera({88, 48}, 176, 96) == {0, 0}
  end

  test "an empty world cell renders exactly the scene span" do
    put_scene(%{{5, 5} => {"x", :green, :blue}})

    lines = Render.world_lines(state({88, 88}), 176, 96)
    assert cell(lines, 5, 5) == %Span{content: "x", style: %Style{fg: :green, bg: :blue}}
  end

  test "an off-scene cell (no stub) falls back to a plain dark floor span" do
    lines = Render.world_lines(state({88, 88}), 176, 96)
    assert cell(lines, 5, 5) == %Span{content: " ", style: %Style{bg: :black}}
  end

  test "attendee sprite composites over the scene: opaque cells win, transparent cells show through" do
    # anchor {50, 50}, sprite 2x2 -> left = 50, top = 49
    # (50, 49) opaque top-left, (51, 49) transparent top-right, (50, 50) anchor (opaque)
    put_scene(%{
      {50, 50} => {"?", :white, :white},
      {51, 49} => {"·", :magenta, nil}
    })

    lines = Render.world_lines(state({50, 50}), 176, 96)

    assert cell(lines, 50, 50) == %Span{content: "█", style: %Style{fg: :cyan, bg: nil}}
    assert cell(lines, 51, 49) == %Span{content: "·", style: %Style{fg: :magenta, bg: nil}}
  end

  test "self's sprite wins over a co-located other" do
    cache =
      Map.put(@avatar_cache, "other_av", %{
        cells: [[{"▓", :magenta, nil}]],
        color: :magenta
      })

    other = %{
      state({50, 50})
      | avatar_cache: cache,
        others_by_pos: %{
          {50, 50} => %{nickname: "o", color: :magenta, avatar_id: "other_av", x: 50, y: 50}
        }
    }

    lines = Render.world_lines(other, 176, 96)
    assert cell(lines, 50, 50) == %Span{content: "█", style: %Style{fg: :cyan, bg: nil}}
  end

  test "name label is centered on the anchor column, bold for self" do
    lines = Render.world_lines(state({50, 50}), 176, 96)
    # label row = 50 - 6 = 44; nickname "me" (len 2) centered: start = 50 - div(2, 2) = 49
    assert cell(lines, 49, 44) == %Span{
             content: "m",
             style: %Style{fg: {:rgb, 9, 9, 9}, modifiers: [:bold]}
           }

    assert cell(lines, 50, 44) == %Span{
             content: "e",
             style: %Style{fg: {:rgb, 9, 9, 9}, modifiers: [:bold]}
           }
  end

  test "an other's name label is dim (not bold) and centered on its own anchor" do
    other = %{
      state({88, 88})
      | others_by_pos: %{
          {80, 50} => %{nickname: "friend", color: :cyan, avatar_id: "av", x: 80, y: 50}
        }
    }

    lines = Render.world_lines(other, 176, 96)
    # label row = 50 - 6 = 44; nickname "friend" (len 6) centered: start = 80 - div(6, 2) = 77
    assert cell(lines, 77, 44) == %Span{content: "f", style: %Style{fg: :cyan}}
    assert cell(lines, 82, 44) == %Span{content: "d", style: %Style{fg: :cyan}}
  end

  test "name label hugs a sprite with transparent top rows" do
    cache =
      Map.put(@avatar_cache, "av", %{cells: @fixture_sprite, color: {:rgb, 9, 9, 9}, top_trim: 2})

    hugged = %{state({50, 50}) | avatar_cache: cache}

    lines = Render.world_lines(hugged, 176, 96)
    # label row = 50 - 6 + 2 = 46 (hugged 2 rows down from the unhugged 44)
    assert cell(lines, 49, 46) == %Span{
             content: "m",
             style: %Style{fg: {:rgb, 9, 9, 9}, modifiers: [:bold]}
           }
  end

  test "a zero-trim sprite's label position is unchanged at y - 6" do
    cache =
      Map.put(@avatar_cache, "av", %{cells: @fixture_sprite, color: {:rgb, 9, 9, 9}, top_trim: 0})

    unhugged = %{state({50, 50}) | avatar_cache: cache}

    lines = Render.world_lines(unhugged, 176, 96)

    assert cell(lines, 49, 44) == %Span{
             content: "m",
             style: %Style{fg: {:rgb, 9, 9, 9}, modifiers: [:bold]}
           }
  end

  test "a fully-transparent (degenerate) sprite clamps its label to y - 1" do
    all_transparent = List.duplicate([{" ", nil, nil}], 6)

    cache =
      Map.put(@avatar_cache, "av", %{cells: all_transparent, color: {:rgb, 9, 9, 9}, top_trim: 6})

    degenerate = %{state({50, 50}) | avatar_cache: cache}

    lines = Render.world_lines(degenerate, 176, 96)
    # naive y - 6 + 6 = 50 (the anchor row itself); clamped to 49 (y - 1)
    assert cell(lines, 49, 49) == %Span{
             content: "m",
             style: %Style{fg: {:rgb, 9, 9, 9}, modifiers: [:bold]}
           }
  end

  test "the 1-cell fallback marker's label sits directly above it, at y - 1" do
    no_cache = %{state({88, 88}) | avatar_cache: %{}}
    lines = Render.world_lines(no_cache, 176, 96)

    # nickname "me" (len 2) centered on x=88: start = 88 - div(2, 2) = 87
    assert cell(lines, 87, 87) == %Span{
             content: "m",
             style: %Style{fg: {:rgb, 9, 9, 9}, modifiers: [:bold]}
           }
  end

  test "name label clamps to world bounds at a world-edge anchor" do
    long = %{
      state({1, 50})
      | attendee: %LobbyTui.Lobby.Attendee{id: "self", nickname: "verylongname", avatar_id: "av"}
    }

    lines = Render.world_lines(long, 176, 96)
    # naive centering would start at 1 - div(12, 2) = -5; clamped to 0
    assert cell(lines, 0, 44) == %Span{
             content: "v",
             style: %Style{fg: {:rgb, 9, 9, 9}, modifiers: [:bold]}
           }
  end

  test "an occupied seat with no sprite anchored on it shows the tint marker in the stored color" do
    seat = {10, 18}
    occupied = %{state({88, 88}) | occupied: %{seat => %{id: "someone-else", color: :magenta}}}

    lines = Render.world_lines(occupied, 176, 96)
    assert cell(lines, 10, 18) == %Span{content: "▪", style: %Style{fg: :magenta}}
  end

  test "an occupied seat's tint falls back to the stored fallback color, not a per-frame default" do
    seat = {10, 18}
    occupied = %{state({88, 88}) | occupied: %{seat => %{id: "someone-else", color: :red}}}

    lines = Render.world_lines(occupied, 176, 96)
    assert cell(lines, 10, 18) == %Span{content: "▪", style: %Style{fg: :red}}
  end

  test "a held seat with an rgb occupant color washes the chair cells toward that color" do
    seat = {10, 18}
    color = {:rgb, 40, 200, 220}
    scene_fg = {:rgb, 100, 100, 100}
    scene_bg = {:rgb, 50, 50, 50}

    # Stub a uniform scene patch around the seat so the wash has chair
    # pixels to blend.
    put_scene(
      for x <- 0..20, y <- 10..20, into: %{} do
        {{x, y}, {"▀", scene_fg, scene_bg}}
      end
    )

    occupied = %{state({88, 88}) | occupied: %{seat => %{id: "someone-else", color: color}}}
    lines = Render.world_lines(occupied, 176, 96)

    # The wash covers the chair core: the footprint minus the breathing
    # column on each side. Every washed cell keeps the scene's glyph but
    # blends both colors toward the occupant's.
    for dx <- -5..4, dy <- -4..0 do
      {x, y} = {elem(seat, 0) + dx, elem(seat, 1) + dy}

      assert cell(lines, x, y) == %Span{
               content: "▀",
               style: %Style{fg: washed(scene_fg, color), bg: washed(scene_bg, color)}
             },
             "expected washed scene cell at #{inspect({x, y})}"
    end

    # One column outside the chair core on each side stays pure scene.
    for {x, y} <- [{10 - 6, 18}, {10 + 5, 18}] do
      assert cell(lines, x, y) == %Span{
               content: "▀",
               style: %Style{fg: scene_fg, bg: scene_bg}
             }
    end
  end

  test "a held seat with an rgb color but no loaded scene falls back to the marker" do
    seat = {10, 18}
    color = {:rgb, 40, 200, 220}
    occupied = %{state({88, 88}) | occupied: %{seat => %{id: "someone-else", color: color}}}

    # Setup leaves the scene empty: there is no chair to wash.
    lines = Render.world_lines(occupied, 176, 96)
    assert cell(lines, 10, 18) == %Span{content: "▪", style: %Style{fg: color}}
  end

  test "an occupied seat with the occupant's sprite on it shows the sprite, not the marker" do
    seat = {10, 18}
    occupied = %{state(seat) | occupied: %{seat => %{id: "self", color: {:rgb, 9, 9, 9}}}}

    lines = Render.world_lines(occupied, 176, 96)
    # anchor at {10, 18}, sprite 2x2 -> left = 10, top = 17; (10, 18) is the opaque anchor cell
    assert cell(lines, 10, 18) == %Span{content: "█", style: %Style{fg: :cyan, bg: nil}}
  end

  test "an anchor with no avatar cache entry at all falls back to a 1-cell bright marker" do
    no_cache = %{state({88, 88}) | avatar_cache: %{}}
    lines = Render.world_lines(no_cache, 176, 96)

    assert cell(lines, 88, 88) == %Span{
             content: "@",
             style: %Style{fg: {:rgb, 9, 9, 9}, modifiers: [:bold]}
           }
  end

  # The feed used to take a band at the bottom of the frame; it plays on
  # the stage now, so the layout no longer changes when the attendee sits
  # and the room never resizes underneath them.
  test "widgets: world plus status row, seated or not" do
    frame = %Frame{width: 60, height: 40}
    assert [{_world, _rect}, {_status, _}] = Render.widgets(state(), frame)

    seated = %{state() | seated?: true}
    assert [{_world, _}, {_status, _}] = Render.widgets(seated, frame)
  end

  test "widgets: the drawn world merges same-styled cells into one span" do
    put_scene(%{
      {0, 0} => {"a", :green, :blue},
      {1, 0} => {"b", :green, :blue},
      {2, 0} => {"c", :red, :blue}
    })

    frame = %Frame{width: 176, height: 97}
    [{%{text: %{lines: drawn}}, _rect}, _status] = Render.widgets(state({88, 88}), frame)
    cells = Render.world_lines(state({88, 88}), 176, 96)

    assert [%Span{content: "ab"}, %Span{content: "c", style: %Style{fg: :red}} | _] =
             hd(drawn).spans

    # Same characters in the same styles, row for row, just fewer spans.
    for {merged, per_cell} <- Enum.zip(drawn, cells) do
      assert graphemes(merged) == graphemes(per_cell)
      assert length(merged.spans) < length(per_cell.spans)
    end

    # The second frame takes the empty rows from Scene's row cache.
    assert [{%{text: %{lines: ^drawn}}, _rect}, _status] = Render.widgets(state({88, 88}), frame)
  end

  defp graphemes(line) do
    Enum.flat_map(line.spans, fn span ->
      span.content |> String.graphemes() |> Enum.map(&{&1, span.style})
    end)
  end

  test "hint appears in the status line" do
    lined = %{state() | hint: "seat taken — try another"}
    frame = %Frame{width: 60, height: 40}
    [_world, {status, _rect}] = Render.widgets(lined, frame)
    assert status.text =~ "seat taken"
  end

  # The status row now renders hints only — the always-on "arrows to
  # move..."/"seated — type below to post" help text duplicated the HTML
  # `#key-bar` (owner screenshot feedback item 4) and has been removed. The
  # row itself stays (a blank row, for layout stability), unseated or
  # seated, whenever no hint is set.
  test "status line is empty (not help text) when unseated with no hint" do
    frame = %Frame{width: 60, height: 40}
    [_world, {status, _rect}] = Render.widgets(state(), frame)
    assert status.text == ""
  end

  test "status line is empty (not help text) when seated with no hint" do
    frame = %Frame{width: 60, height: 40}
    seated = %{state() | seated?: true}
    [_world, {status, _rect}] = Render.widgets(seated, frame)
    assert status.text == ""
  end

  describe "the stage" do
    @stage_center div(176, 2)
    @vh 40

    defp seated_state(curtain, feed \\ []) do
      seat = Enum.find(World.seats(), &(&1.row == 8 and &1.col == 6))

      %{
        state({seat.x, seat.y})
        | seated?: true,
          curtain: curtain,
          feed: feed
      }
    end

    defp msg(nickname, body), do: %{author_nickname: nickname, body: body}

    # `world_lines/3` returns only the rows the viewport covers, and a
    # seated viewport is anchored at the bottom of the world — so a world
    # row has to be shifted by the camera origin to index into them.
    defp seated_origin_y(vh \\ @vh), do: World.height() - vh
    defp stage_cell(lines, x, world_y), do: cell(lines, x, world_y - seated_origin_y())

    # A row well inside the drape, clear of the apron and the far edge.
    defp curtain_row, do: World.stage_rows().last - 1

    test "the camera drops to the stage when seated and follows the attendee otherwise" do
      # The stage runs along the bottom of the world, so framing it means
      # anchoring at the last row the viewport can reach.
      standing = state({20, 30})
      assert {_ox, standing_oy} = Render.viewport_origin(standing, 60, 40)

      seated = seated_state(0)
      assert {ox, seated_oy} = Render.viewport_origin(seated, 60, 40)

      assert seated_oy == World.height() - 40
      assert seated_oy > standing_oy, "sitting should carry the camera down to the stage"
      assert ox == @stage_center - 30

      for y <- World.stage_rows(), do: assert(y in seated_oy..(seated_oy + 39))
    end

    test "a shut curtain paints nothing, leaving the scene's own drape" do
      lines = Render.world_lines(seated_state(0), 176, @vh)
      # Scene is stubbed empty in setup, so an unpainted stage cell falls
      # back to the plain floor span rather than any stage colour.
      assert %Span{style: %Style{bg: :black}} = stage_cell(lines, 30, curtain_row())
    end

    test "a fully open curtain clears the whole band, symmetrically" do
      steps = LobbyTui.Theatre.curtain_steps()
      lines = Render.world_lines(seated_state(steps), 176, @vh)

      centre = stage_cell(lines, @stage_center, curtain_row())
      assert %Span{style: %Style{bg: {:rgb, _, _, _}}} = centre

      # Equal reach either side of the proscenium's centre line.
      for offset <- [10, 40, 80] do
        assert stage_cell(lines, @stage_center - offset, curtain_row()).style.bg ==
                 centre.style.bg

        assert stage_cell(lines, @stage_center + offset, curtain_row()).style.bg ==
                 centre.style.bg
      end
    end

    test "a half-open curtain has cleared the middle but not the wings" do
      steps = LobbyTui.Theatre.curtain_steps()
      lines = Render.world_lines(seated_state(div(steps, 2)), 176, @vh)

      opened = stage_cell(lines, @stage_center, curtain_row()).style.bg
      assert opened != :black
      assert stage_cell(lines, 6, curtain_row()).style.bg == :black
    end

    test "the apron never travels with the drape" do
      steps = LobbyTui.Theatre.curtain_steps()
      lines = Render.world_lines(seated_state(steps), 176, @vh)

      for y <- World.apron_rows() do
        assert stage_cell(lines, @stage_center, y).style.bg == :black
      end
    end

    defp stage_text(lines) do
      for y <- World.stage_rows() do
        lines
        |> Enum.at(y - seated_origin_y())
        |> Map.fetch!(:spans)
        |> Enum.map_join(& &1.content)
        |> String.trim()
      end
    end

    test "messages play on the stage, newest on the bottom line" do
      steps = LobbyTui.Theatre.curtain_steps()
      feed = [msg("ana", "second"), msg("gus", "first")]
      lines = Render.world_lines(seated_state(steps, feed), 176, @vh)

      text = lines |> stage_text() |> Enum.reject(&(&1 == ""))

      assert length(text) == 2
      assert List.first(text) =~ "gus: first"
      assert List.last(text) =~ "ana: second"
    end

    test "a scrolled feed leafs back: newest hidden, an older message on the bottom line" do
      steps = LobbyTui.Theatre.curtain_steps()
      feed = [msg("c", "newest"), msg("b", "middle"), msg("a", "oldest")]
      scrolled = %{seated_state(steps, feed) | feed_scroll: 1}

      text =
        Render.world_lines(scrolled, 176, @vh) |> stage_text() |> Enum.reject(&(&1 == ""))

      assert List.last(text) =~ "b: middle"
      assert List.first(text) =~ "a: oldest"
      refute Enum.any?(text, &(&1 =~ "newest"))
    end

    test "the author's nickname plays in their avatar's dominant color" do
      steps = LobbyTui.Theatre.curtain_steps()
      feed = [%{author_nickname: "gus", body: "hi", author_avatar_id: "av"}]
      lines = Render.world_lines(seated_state(steps, feed), 176, @vh)

      bottom = World.stage_rows().last - 1
      spans = lines |> Enum.at(bottom - seated_origin_y()) |> Map.fetch!(:spans)

      # "av"'s cache entry carries color {:rgb, 9, 9, 9}.
      assert Enum.any?(spans, &(&1.content == "g" and &1.style.fg == {:rgb, 9, 9, 9}))
    end

    test "a message without a resolvable avatar keeps the neutral author color" do
      steps = LobbyTui.Theatre.curtain_steps()
      no_cache = %{seated_state(steps, [msg("ana", "yo")]) | avatar_cache: %{}}
      lines = Render.world_lines(no_cache, 176, @vh)

      bottom = World.stage_rows().last - 1
      spans = lines |> Enum.at(bottom - seated_origin_y()) |> Map.fetch!(:spans)

      assert Enum.any?(spans, &(&1.content == "a" and &1.style.fg == {:rgb, 34, 206, 222}))
    end

    defp with_marquee(state) do
      anim = Ascii.new!("marquee", parts: true, options: %{text: "now showing"})
      {frame, _anim} = Ascii.frame(anim, 1.0)
      %{state | marquee_frame: frame}
    end

    test "an open stage with an empty feed plays the marquee sign" do
      steps = LobbyTui.Theatre.curtain_steps()
      lines = Render.world_lines(with_marquee(seated_state(steps)), 176, @vh)
      text = stage_text(lines)

      # Its frame of bulbs and box drawing, centred on the stage.
      assert Enum.any?(text, &(&1 =~ "╔═══"))
      assert Enum.any?(text, &(&1 =~ "╚═══"))

      # The sign is 61×10, the opening's full height: its top-left bulb sits
      # on the first drape row. Coloured parts keep their ink, all of it on
      # the stage interior.
      top = World.stage_rows().last - 9

      assert %Span{content: bulb, style: %Style{fg: {:rgb, _, _, _}, bg: interior}} =
               stage_cell(lines, @stage_center - 30, top)

      assert bulb in ["o", "·"]
      assert interior == stage_cell(lines, @stage_center, curtain_row()).style.bg
    end

    test "the marquee gives way to the first message" do
      steps = LobbyTui.Theatre.curtain_steps()
      state = with_marquee(seated_state(steps, [msg("gus", "hello")]))
      text = Render.world_lines(state, 176, @vh) |> stage_text()

      assert Enum.any?(text, &(&1 =~ "gus: hello"))
      refute Enum.any?(text, &(&1 =~ "╔═══"))
    end

    test "the marquee comes down with the curtain" do
      steps = LobbyTui.Theatre.curtain_steps()
      lines = Render.world_lines(with_marquee(seated_state(steps - 1)), 176, @vh)

      refute Enum.any?(stage_text(lines), &(&1 =~ "╔═══"))
    end

    test "messages stay hidden until the curtain is all the way open" do
      steps = LobbyTui.Theatre.curtain_steps()
      feed = [msg("gus", "hello")]
      lines = Render.world_lines(seated_state(steps - 1, feed), 176, @vh)

      refute Enum.any?(stage_text(lines), &(&1 =~ "hello"))
    end
  end
end
