defmodule LobbyTui.Theatre.RenderTest do
  # Scene is a single global `:persistent_term` slot; the setup below stubs
  # it to empty for deterministic assertions and restores the real boot
  # value on exit, so this file cannot run concurrently with anything else
  # touching Scene.
  use ExUnit.Case, async: false

  alias ExRatatui.Frame
  alias ExRatatui.Style
  alias ExRatatui.Text.Span
  alias LobbyTui.Theatre.{Render, State}
  alias LobbyTui.World

  @scene_key {LobbyTui.Scene, :cells}

  # 2 cols x 2 rows: opaque top-left, transparent top-right, opaque bottom
  # row (bottom-left is the anchor cell itself). Deliberately not 12x6 —
  # the compositor must not assume the standard sprite size.
  @fixture_sprite [
    [{"█", :cyan, nil}, {" ", nil, nil}],
    [{"█", :cyan, nil}, {"█", :cyan, nil}]
  ]

  @avatar_cache %{"av" => %{cells: @fixture_sprite, color: {:rgb, 9, 9, 9}}}

  setup do
    original = :persistent_term.get(@scene_key, %{})
    :persistent_term.put(@scene_key, %{})
    on_exit(fn -> :persistent_term.put(@scene_key, original) end)
    :ok
  end

  defp put_scene(cells), do: :persistent_term.put(@scene_key, cells)

  defp state(pos \\ World.spawn_point()) do
    attendee = %LobbyTui.Lobby.Attendee{id: "self", nickname: "me", avatar_id: "av"}
    %{State.new(attendee, {:rgb, 9, 9, 9}, @avatar_cache) | pos: pos}
  end

  defp cell(lines, x, y), do: lines |> Enum.at(y) |> Map.fetch!(:spans) |> Enum.at(x)

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

  test "widgets: world only when unseated, world + feed panel when seated" do
    frame = %Frame{width: 60, height: 40}
    assert [{_world, _rect}, {_status, _}] = Render.widgets(state(), frame)

    seated = %{state() | seated?: true}
    assert [{_world, _}, {_feed, _}, {_status, _}] = Render.widgets(seated, frame)
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
    [_world, {_feed, _}, {status, _rect}] = Render.widgets(seated, frame)
    assert status.text == ""
  end
end
