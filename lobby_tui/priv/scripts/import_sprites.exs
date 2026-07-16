# Imports downloaded pixel-art packs into 12x12 avatar candidates plus an HTML
# naming sheet, then applies a hand-written names CSV into priv/sprites_src/.
# The logic lives in LobbyTui.Scripts.SpriteImport (lib/lobby_tui/scripts/sprite_import.ex)
# so slicing, normalization, and validation are testable.
#
# Run:
#   mix run priv/scripts/import_sprites.exs extract <workdir> <prefix>:<path> [<prefix>:<path>...]
#   mix run priv/scripts/import_sprites.exs apply <workdir> <names.csv>

usage =
  "usage: import_sprites.exs extract <workdir> <prefix>:<path> [<prefix>:<path>...] | " <>
    "apply <workdir> <names.csv>"

parse_source = fn arg ->
  case String.split(arg, ":", parts: 2) do
    [prefix, path] -> {prefix, path}
    [_] -> nil
  end
end

case System.argv() do
  ["extract", workdir | raw_sources] when raw_sources != [] ->
    sources = Enum.map(raw_sources, parse_source)

    if Enum.any?(sources, &is_nil/1) do
      IO.puts(usage)
    else
      %{counts: counts, index_html: index_html} =
        LobbyTui.Scripts.SpriteImport.extract(sources, workdir)

      Enum.each(counts, fn {prefix, count} -> IO.puts("#{prefix}: #{count} tiles kept") end)
      IO.puts("naming sheet: #{index_html}")
    end

  ["apply", workdir, csv] ->
    case LobbyTui.Scripts.SpriteImport.apply(csv, workdir) do
      {:ok, count} ->
        IO.puts("copied #{count} sprites to #{LobbyTui.Scripts.SpriteImport.default_dest()}")

      {:error, reasons} ->
        Enum.each(reasons, &IO.puts/1)
    end

  _ ->
    IO.puts(usage)
end
