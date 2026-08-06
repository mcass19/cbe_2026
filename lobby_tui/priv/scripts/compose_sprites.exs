# Composites the Kenney Roguelike Characters sheet into per-tile villager
# PNGs plus a names.csv, ready for import_sprites.exs extract/apply. The
# logic lives in LobbyTui.Scripts.SpriteCompose
# (lib/lobby_tui/scripts/sprite_compose.ex) so slicing, compositing, and
# validation are testable.
#
# Run:
#   mix run priv/scripts/compose_sprites.exs <roguelikeChar_transparent.png> <workdir>

case System.argv() do
  [sheet, workdir] ->
    case LobbyTui.Scripts.SpriteCompose.run(sheet, workdir) do
      {:ok, count} ->
        IO.puts("composited #{count} villagers into #{workdir}")

      {:error, reasons} ->
        Enum.each(reasons, &IO.puts/1)
    end

  _ ->
    IO.puts("usage: compose_sprites.exs <roguelikeChar_transparent.png> <workdir>")
end
