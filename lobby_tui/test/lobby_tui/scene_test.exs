defmodule LobbyTui.SceneTest do
  use ExUnit.Case, async: false

  alias LobbyTui.Scene
  alias LobbyTui.Scripts.PlaceholderScene
  alias LobbyTui.World

  defp rgb({r, g, b}), do: {:rgb, r, g, b}

  test "the default theatre.png loads at boot, spanning the full 176x96 grid" do
    assert Scene.loaded?()
    # last valid cell of a 176x96 grid: col 175, row 95
    assert {_char, _fg, _bg} = Scene.cell({World.width() - 1, World.height() - 1})
    # one past the edge in either axis is off-scene
    assert Scene.cell({World.width(), World.height() - 1}) == nil
    assert Scene.cell({World.width() - 1, World.height()}) == nil
  end

  test "a stage-band cell carries a curtain palette color" do
    palette = PlaceholderScene.palette()
    curtain_colors = Enum.map(palette.curtain_folds, &rgb/1)

    # A row inside the drape, below the valance; col 30 sits well away from
    # the trim and the curtain's edge shadows.
    row = World.stage_rows().last - 1
    assert {_char, fg, bg} = Scene.cell({30, row})
    assert fg in curtain_colors or bg in curtain_colors
  end

  test "a lobby-band cell differs from the auditorium floorboards" do
    palette = PlaceholderScene.palette()
    floor_colors = [rgb(palette.floor), rgb(palette.floor_seam), rgb(palette.floor_hi)]

    # A row inside the lobby carpet, clear of the dithered edge that faces
    # the seats; col 50 avoids the trim and aisle margins.
    row = World.lobby_rows().first + 1
    assert {_char, fg, bg} = Scene.cell({50, row})
    refute fg in floor_colors
    refute bg in floor_colors
  end

  test "a missing scene PNG logs a warning and yields an empty scene" do
    missing_path =
      Path.join(
        System.tmp_dir!(),
        "lobby_tui_scene_missing_#{System.unique_integer([:positive])}.png"
      )

    Application.put_env(:lobby_tui, :scene_path, missing_path)

    on_exit(fn ->
      Application.delete_env(:lobby_tui, :scene_path)
      Scene.load!()
    end)

    log = ExUnit.CaptureLog.capture_log(fn -> Scene.load!() end)
    assert log =~ "Scene"

    refute Scene.loaded?()
    assert Scene.cell({30, 3}) == nil
  end

  test "a corrupt scene PNG logs a warning and yields an empty scene" do
    path =
      Path.join(
        System.tmp_dir!(),
        "lobby_tui_scene_corrupt_#{System.unique_integer([:positive])}.png"
      )

    File.write!(path, "not a png")
    Application.put_env(:lobby_tui, :scene_path, path)

    on_exit(fn ->
      Application.delete_env(:lobby_tui, :scene_path)
      File.rm_rf!(path)
      Scene.load!()
    end)

    log = ExUnit.CaptureLog.capture_log(fn -> Scene.load!() end)
    assert log =~ "Scene"

    refute Scene.loaded?()
    assert Scene.cell({30, 3}) == nil
  end
end
