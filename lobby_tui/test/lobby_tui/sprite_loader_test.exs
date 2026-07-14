defmodule LobbyTui.SpriteLoaderTest do
  use ExUnit.Case, async: false

  test "load_all! seeds one avatar per source PNG plus the unknown fallback" do
    LobbyTui.SpriteLoader.load_all!()
    avatars = LobbyTui.Lobby.list_avatars!()
    names = Enum.map(avatars, & &1.name)

    assert "unknown" in names
    assert "crimson" in names
    assert Enum.count(names) >= 9

    crimson = Enum.find(avatars, &(&1.name == "crimson"))
    assert [[{_, _, _} | _] | _] = crimson.sprite_cells
    assert {:rgb, 220, 60, 60} = crimson.dominant_color
  end

  test "a corrupt png is skipped with a warning, boot still succeeds" do
    dir = Path.join(System.tmp_dir!(), "lobby_tui_sprites_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    good_source = Path.join([:code.priv_dir(:lobby_tui), "sprites_src", "crimson.png"])
    File.cp!(good_source, Path.join(dir, "crimson.png"))
    File.write!(Path.join(dir, "broken.png"), "not a png")

    Application.put_env(:lobby_tui, :sprites_dir, dir)

    on_exit(fn ->
      Application.delete_env(:lobby_tui, :sprites_dir)
      File.rm_rf!(dir)
    end)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        LobbyTui.SpriteLoader.load_all!()
      end)

    assert log =~ "broken.png"

    names = LobbyTui.Lobby.list_avatars!() |> Enum.map(& &1.name)
    assert "crimson" in names
  end
end
