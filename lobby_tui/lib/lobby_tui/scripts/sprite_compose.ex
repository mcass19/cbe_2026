defmodule LobbyTui.Scripts.SpriteCompose do
  @moduledoc """
  Dev-time compositing pipeline for Kenney's Roguelike Characters pack
  (https://kenney.nl/assets/roguelike-characters, CC0). The sheet is
  modular — base bodies, outfits, hair, and hats as separate 16×16 layers
  on a 17px stride (1px gutter) — so `run/3` slices it and paints each
  recipe's layers over its base, writing per-tile PNGs plus a `names.csv`
  that `SpriteImport.extract/2` (directory mode) and `SpriteImport.apply/3`
  consume unchanged.

  Recipes are hand-curated, ordered, and deterministic: the Nth recipe
  always becomes `villager_NNNN.png` named by its own entry, so re-runs
  are reproducible. Invoked by `priv/scripts/compose_sprites.exs`.
  """

  alias LobbyTui.SpriteLoader.Png

  # The published sheet's exact dimensions; anything else means the wrong
  # file was downloaded, so run/3 refuses it.
  @sheet_width 918
  @sheet_height 203

  # 16×16 cells separated by a 1px gutter, no leading margin.
  @stride 17
  @cell 16
  @max_col 53
  @max_row 11

  # Held to SpriteImport's closed character set for avatar names.
  @name_pattern ~r/^[a-z0-9][a-z0-9_-]*$/

  # Mirrors SpriteImport/Converter semantics: alpha >= 128 is opaque.
  @alpha_threshold 128

  # Format: {name, base_cell, layer_cells}. Cells are {col, row} on the
  # 54×12 grid. The first 14 are the pack's pre-dressed characters (cols
  # 0–1, rows 5–11); the remaining 61 layer a torso (cols 6–17) and often
  # hair/beard (cols 19–26) or a hat (cols 28–31) over a nude base (cols
  # 0–1, rows 0–3 — four skin tones).
  @recipes [
    {"ada", {0, 5}, []},
    {"gus", {1, 5}, []},
    {"mia", {0, 6}, []},
    {"ben", {1, 6}, []},
    {"kai", {0, 7}, []},
    {"sol", {1, 7}, []},
    {"ivy", {0, 8}, []},
    {"rex", {1, 8}, []},
    {"una", {0, 9}, []},
    {"taro", {1, 9}, []},
    {"wren", {0, 10}, []},
    {"otis", {1, 10}, []},
    {"faye", {0, 11}, []},
    {"hollis", {1, 11}, []},
    {"luz", {0, 0}, [{6, 0}, {19, 0}]},
    {"remy", {1, 1}, [{7, 3}, {20, 11}]},
    {"nell", {0, 2}, [{8, 6}, {22, 10}]},
    {"cato", {1, 3}, [{9, 9}, {25, 5}, {31, 4}]},
    {"elsa", {0, 0}, [{10, 2}]},
    {"finn", {1, 1}, [{11, 5}, {21, 11}]},
    {"greta", {0, 2}, [{12, 8}, {24, 2}]},
    {"hugo", {1, 3}, [{13, 1}, {19, 1}]},
    {"iris", {0, 0}, [{14, 4}, {28, 1}]},
    {"jules", {1, 1}, [{15, 7}]},
    {"kira", {0, 2}, [{16, 0}, {25, 6}]},
    {"lino", {1, 3}, [{17, 3}, {20, 1}]},
    {"mira", {0, 0}, [{6, 7}, {22, 0}]},
    {"nils", {1, 1}, [{7, 0}, {24, 3}, {29, 9}]},
    {"opal", {0, 2}, [{8, 3}]},
    {"pere", {1, 3}, [{9, 6}, {21, 1}]},
    {"quinn", {0, 0}, [{10, 9}, {23, 0}]},
    {"rosa", {1, 1}, [{11, 2}, {25, 7}]},
    {"sten", {0, 2}, [{12, 5}, {28, 7}]},
    {"tilda", {1, 3}, [{13, 8}]},
    {"ugo", {0, 0}, [{14, 1}, {24, 4}]},
    {"vera", {1, 1}, [{15, 4}, {19, 3}]},
    {"wim", {0, 2}, [{16, 7}, {21, 2}]},
    {"xena", {1, 3}, [{17, 0}, {24, 1}, {28, 1}]},
    {"yuri", {0, 0}, [{6, 4}]},
    {"zola", {1, 1}, [{7, 7}, {20, 3}]},
    {"alba", {0, 2}, [{8, 0}, {22, 2}]},
    {"bruno", {1, 3}, [{9, 3}, {24, 5}]},
    {"cleo", {0, 0}, [{10, 6}, {29, 9}]},
    {"dino", {1, 1}, [{11, 9}]},
    {"edda", {0, 2}, [{12, 2}, {23, 2}]},
    {"floro", {1, 3}, [{13, 5}, {26, 1}]},
    {"gilda", {0, 0}, [{14, 8}, {20, 4}]},
    {"hank", {1, 1}, [{15, 1}, {22, 3}, {30, 8}]},
    {"inge", {0, 2}, [{16, 4}]},
    {"jorn", {1, 3}, [{17, 7}, {19, 5}]},
    {"kaja", {0, 0}, [{6, 1}, {21, 4}]},
    {"lars", {1, 1}, [{7, 4}, {23, 3}]},
    {"mona", {0, 2}, [{8, 7}, {30, 5}]},
    {"nino", {1, 3}, [{9, 0}]},
    {"oda", {0, 0}, [{10, 3}, {22, 4}]},
    {"pia", {1, 1}, [{11, 6}, {24, 7}]},
    {"ravn", {0, 2}, [{12, 9}, {19, 6}]},
    {"siv", {1, 3}, [{13, 2}, {21, 5}, {29, 9}]},
    {"tove", {0, 0}, [{14, 5}]},
    {"ulla", {1, 1}, [{15, 8}, {26, 3}]},
    {"vidar", {0, 2}, [{16, 1}, {20, 6}]},
    {"willa", {1, 3}, [{17, 4}, {22, 5}]},
    {"xavi", {0, 0}, [{6, 8}, {29, 3}]},
    {"yrsa", {1, 1}, [{7, 1}]},
    {"zeno", {0, 2}, [{8, 4}, {21, 6}]},
    {"aina", {1, 3}, [{9, 7}, {23, 5}]},
    {"bodil", {0, 0}, [{10, 0}, {26, 4}]},
    {"cyra", {1, 1}, [{11, 3}, {20, 7}, {31, 7}]},
    {"dag", {0, 2}, [{12, 6}]},
    {"eyra", {1, 3}, [{13, 9}, {25, 1}]},
    {"frode", {0, 0}, [{14, 2}, {19, 8}]},
    {"gry", {1, 1}, [{15, 5}, {21, 7}]},
    {"hedda", {0, 2}, [{16, 8}, {28, 5}]},
    {"idun", {1, 3}, [{17, 1}]},
    {"jarl", {0, 0}, [{6, 5}, {20, 8}]}
  ]

  @doc "The curated recipe list applied by default."
  def recipes, do: @recipes

  @doc """
  Slices `sheet_path`, composites every recipe, and writes
  `<workdir>/tiles/villager_NNNN.png` plus `<workdir>/names.csv`.

  Every recipe is validated before anything is written: the sheet must be
  exactly #{@sheet_width}×#{@sheet_height}, every cell within the
  54×12 grid, every name within the avatar name character set, and no
  name repeated. Any violation returns `{:error, reasons}` listing every
  offense and writes nothing; otherwise returns `{:ok, count}`.
  """
  def run(sheet_path, workdir, recipes \\ recipes()) do
    {:ok, rows} = Png.decode(sheet_path)

    case validate(rows, recipes) do
      [] -> write_all(rows, workdir, recipes)
      reasons -> {:error, reasons}
    end
  end

  defp validate(rows, recipes) do
    dimensions(rows) ++ cells(recipes) ++ names(recipes)
  end

  defp dimensions([first | _] = rows) do
    height = length(rows)
    width = length(first)

    if width == @sheet_width and height == @sheet_height do
      []
    else
      ["sheet must be #{@sheet_width}x#{@sheet_height}, got #{width}x#{height}"]
    end
  end

  defp cells(recipes) do
    for {name, base, layers} <- recipes,
        {col, row} <- [base | layers],
        col not in 0..@max_col or row not in 0..@max_row do
      "cell out of range: {#{col}, #{row}} (recipe: #{name})"
    end
  end

  defp names(recipes) do
    invalid =
      for {name, _base, _layers} <- recipes,
          not Regex.match?(@name_pattern, name) do
        "invalid recipe name: #{inspect(name)}"
      end

    duplicates =
      recipes
      |> Enum.frequencies_by(fn {name, _base, _layers} -> name end)
      |> Enum.filter(fn {_name, count} -> count > 1 end)
      |> Enum.map(fn {name, _count} -> "duplicate recipe name: #{name}" end)

    invalid ++ duplicates
  end

  defp write_all(rows, workdir, recipes) do
    tiles_dir = Path.join(workdir, "tiles")
    File.mkdir_p!(tiles_dir)

    recipes
    |> Enum.with_index()
    |> Enum.each(fn {{_name, base, layers}, index} ->
      tile = Enum.reduce(layers, tile_at(rows, base), &overlay(&2, tile_at(rows, &1)))
      write_png!(Path.join(tiles_dir, "villager_#{pad(index)}.png"), tile)
    end)

    csv =
      recipes
      |> Enum.with_index()
      |> Enum.map_join(fn {{name, _base, _layers}, index} ->
        "villager_#{pad(index)}.png,#{name}\n"
      end)

    File.write!(Path.join(workdir, "names.csv"), csv)
    {:ok, length(recipes)}
  end

  defp tile_at(rows, {col, row}) do
    rows
    |> Enum.slice(row * @stride, @cell)
    |> Enum.map(&Enum.slice(&1, col * @stride, @cell))
  end

  defp overlay(base_tile, layer_tile) do
    Enum.zip_with(base_tile, layer_tile, fn base_row, layer_row ->
      Enum.zip_with(base_row, layer_row, &pick/2)
    end)
  end

  defp pick(_base_pixel, {_r, _g, _b, a} = layer_pixel) when a >= @alpha_threshold,
    do: layer_pixel

  defp pick(base_pixel, _layer_pixel), do: base_pixel

  defp pad(index), do: index |> Integer.to_string() |> String.pad_leading(4, "0")

  defp write_png!(path, rows) do
    canvas =
      Enum.map(rows, fn row ->
        Enum.map(row, fn {r, g, b, a} -> ExPng.Color.rgba(r, g, b, a) end)
      end)

    {:ok, ^path} = ExPng.Image.to_file(ExPng.Image.new(canvas), path)
  end
end
