defmodule LobbyTui.SpriteLoaderTest do
  use ExUnit.Case, async: false

  # A generated fixture keeps these tests independent of the curated sprite
  # set in priv/sprites_src/ — renaming or replacing shipped avatars must not
  # break the loader's own contract.
  defp fixture_dir! do
    dir = Path.join(System.tmp_dir!(), "lobby_tui_sprites_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    scarlet = ExPng.Color.rgba(220, 60, 60, 255)
    canvas = for _ <- 1..12, do: for(_ <- 1..12, do: scarlet)
    path = Path.join(dir, "scarlet.png")
    {:ok, ^path} = ExPng.Image.to_file(ExPng.Image.new(canvas), path)

    Application.put_env(:lobby_tui, :sprites_dir, dir)

    on_exit(fn ->
      Application.delete_env(:lobby_tui, :sprites_dir)
      File.rm_rf!(dir)
    end)

    dir
  end

  test "load_all! seeds one avatar per source PNG plus the unknown fallback" do
    fixture_dir!()
    LobbyTui.SpriteLoader.load_all!()

    avatars = LobbyTui.Lobby.list_avatars!()
    names = Enum.map(avatars, & &1.name)

    assert "unknown" in names
    assert "scarlet" in names

    scarlet = Enum.find(avatars, &(&1.name == "scarlet"))
    assert [[{_, _, _} | _] | _] = scarlet.sprite_cells
    assert {:rgb, 220, 60, 60} = scarlet.dominant_color
  end

  test "a corrupt png is skipped with a warning, boot still succeeds" do
    dir = fixture_dir!()
    File.write!(Path.join(dir, "broken.png"), "not a png")

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        LobbyTui.SpriteLoader.load_all!()
      end)

    assert log =~ "broken.png"

    names = LobbyTui.Lobby.list_avatars!() |> Enum.map(& &1.name)
    assert "scarlet" in names
  end
end
