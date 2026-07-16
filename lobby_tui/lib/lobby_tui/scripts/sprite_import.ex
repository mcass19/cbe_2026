defmodule LobbyTui.Scripts.SpriteImport do
  @moduledoc """
  Dev-time sprite import pipeline. `extract/2` turns downloaded pixel-art
  packs — spritesheet PNGs or directories of per-tile PNGs — into 12×12
  avatar candidates under `<workdir>/raw/` plus a self-contained HTML naming
  sheet at `<workdir>/index.html`. After the sheet's `names.csv` is filled in
  by hand, `apply/3` validates every row and copies the named tiles into
  `priv/sprites_src/`.

  Invoked by `priv/scripts/import_sprites.exs`; lives in `lib/` (not inline
  in the script) so the slicing, normalization, and validation logic is
  testable.
  """

  alias LobbyTui.SpriteLoader.Png

  # Spritesheets are sliced into fixed 16×16 cells, row-major; a ragged
  # remainder (dimensions not divisible by the cell size) is ignored.
  @cell 16

  # Every kept tile is canvas-fit to exactly 12×12: center crop when a
  # dimension is larger, center pad with transparent pixels when smaller
  # (offset = div(delta, 2) on the leading edge). Never scaled.
  @size 12

  # Mirrors the runtime loader's Converter semantics: alpha >= 128 is opaque.
  @alpha_threshold 128
  @transparent {0, 0, 0, 0}

  @name_pattern ~r/^[a-z0-9][a-z0-9_-]*$/

  @doc """
  Extracts 12×12 tile candidates from `sources` (a list of `{prefix, path}`
  where `path` is a spritesheet PNG or a directory of per-tile PNGs) into
  `<workdir>/raw/` and writes the naming sheet at `<workdir>/index.html`.
  Prefixes become part of filenames and HTML attributes, so they are held to
  the same closed character set as avatar names.

  Returns `%{counts: [{prefix, kept_count}], index_html: path}`.
  """
  def extract(sources, workdir) do
    Enum.each(sources, fn {prefix, _path} -> validate_prefix!(prefix) end)

    raw_dir = Path.join(workdir, "raw")
    File.mkdir_p!(raw_dir)

    sections = Enum.map(sources, &extract_source(&1, raw_dir))

    index_html = Path.join(workdir, "index.html")
    File.write!(index_html, render_index(sections))

    counts = Enum.map(sections, fn {prefix, files} -> {prefix, length(files)} end)
    %{counts: counts, index_html: index_html}
  end

  @doc """
  Applies a hand-written names CSV (lines of `raw_name,avatar_name`, blank
  lines ignored) by copying each raw tile to `<dest>/<avatar_name>.png`.

  Every row is validated before anything is copied: the raw name must be a
  plain filename (no path separators) for a file that exists under
  `<workdir>/raw/`, the avatar name (after trim + downcase, with a stray
  trailing `.png` stripped) must match `^[a-z0-9][a-z0-9_-]*$`, and no
  avatar name may repeat. Any violation returns `{:error, reasons}` listing
  every offending row and copies nothing; otherwise returns `{:ok, count}`.
  """
  def apply(csv_path, workdir, dest \\ default_dest()) do
    rows = parse_csv(csv_path)

    case validate(rows, workdir) do
      [] ->
        File.mkdir_p!(dest)

        Enum.each(rows, fn {raw, name} ->
          File.cp!(Path.join([workdir, "raw", raw]), Path.join(dest, "#{name}.png"))
        end)

        {:ok, length(rows)}

      reasons ->
        {:error, reasons}
    end
  end

  @doc "The default `apply/3` destination: the app's `priv/sprites_src/`."
  def default_dest, do: Path.join([:code.priv_dir(:lobby_tui), "sprites_src"])

  ## extract

  defp validate_prefix!(prefix) do
    if not Regex.match?(@name_pattern, prefix) do
      raise ArgumentError,
            "invalid prefix #{inspect(prefix)}: allowed are lowercase letters, digits, _ and -"
    end
  end

  defp extract_source({prefix, path}, raw_dir) do
    files =
      path
      |> load_tiles()
      |> Enum.map(fn {number, rows} -> {number, normalize(rows)} end)
      |> Enum.filter(fn {_number, tile} -> any_opaque?(tile) end)
      |> Enum.map(fn {number, tile} ->
        file = "#{prefix}_#{number}.png"
        write_png!(Path.join(raw_dir, file), tile)
        file
      end)

    {prefix, files}
  end

  defp load_tiles(path) do
    if File.dir?(path), do: directory_tiles(path), else: sheet_tiles(path)
  end

  defp directory_tiles(dir) do
    {tiles, _used} =
      dir
      |> Path.join("*.png")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.with_index()
      |> Enum.map_reduce(MapSet.new(), fn {file, index}, used ->
        number = unique_number(tile_number(file, index), used)
        {:ok, rows} = Png.decode(file)
        {{number, rows}, MapSet.put(used, number)}
      end)

    tiles
  end

  # The raw number comes from the source filename's trailing digits when
  # present (preserving the pack's own numbering), else the file's index.
  defp tile_number(file, index) do
    case Regex.run(~r/(\d+)$/, Path.basename(file, ".png")) do
      [_, digits] -> digits |> String.to_integer() |> format_number()
      nil -> format_number(index)
    end
  end

  defp format_number(n), do: n |> Integer.to_string() |> String.pad_leading(4, "0")

  # A number already claimed by an earlier file falls back to the lowest
  # free one, so two source files can never overwrite each other's tile.
  defp unique_number(preferred, used) do
    if MapSet.member?(used, preferred) do
      0
      |> Stream.iterate(&(&1 + 1))
      |> Stream.map(&format_number/1)
      |> Enum.find(&(not MapSet.member?(used, &1)))
    else
      preferred
    end
  end

  defp sheet_tiles(path) do
    {:ok, rows} = Png.decode(path)

    rows
    |> Enum.chunk_every(@cell)
    |> Enum.filter(&(length(&1) == @cell))
    |> Enum.flat_map(fn band ->
      band
      |> Enum.map(fn row ->
        row |> Enum.chunk_every(@cell) |> Enum.filter(&(length(&1) == @cell))
      end)
      |> Enum.zip_with(&Function.identity/1)
    end)
    |> Enum.with_index()
    |> Enum.map(fn {cell, index} -> {format_number(index), cell} end)
  end

  defp normalize(rows) do
    rows
    |> Enum.map(fn row -> row |> Enum.map(&threshold/1) |> fit(@transparent) end)
    |> fit(List.duplicate(@transparent, @size))
  end

  defp threshold({r, g, b, a}) when a >= @alpha_threshold, do: {r, g, b, 255}
  defp threshold(_pixel), do: @transparent

  defp fit(items, _pad) when length(items) >= @size do
    items |> Enum.drop(div(length(items) - @size, 2)) |> Enum.take(@size)
  end

  defp fit(items, pad) do
    lead = div(@size - length(items), 2)
    trail = @size - length(items) - lead
    List.duplicate(pad, lead) ++ items ++ List.duplicate(pad, trail)
  end

  defp any_opaque?(rows) do
    Enum.any?(rows, fn row -> Enum.any?(row, &match?({_, _, _, 255}, &1)) end)
  end

  defp write_png!(path, rows) do
    canvas =
      Enum.map(rows, fn row ->
        Enum.map(row, fn {r, g, b, a} -> ExPng.Color.rgba(r, g, b, a) end)
      end)

    {:ok, ^path} = ExPng.Image.to_file(ExPng.Image.new(canvas), path)
  end

  ## apply

  defp parse_csv(csv_path) do
    csv_path
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_row/1)
  end

  defp parse_row(line) do
    case String.split(line, ",", parts: 2) do
      [raw, name] -> {String.trim(raw), normalize_name(name)}
      [raw] -> {String.trim(raw), ""}
    end
  end

  defp normalize_name(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace_suffix(".png", "")
  end

  defp validate(rows, workdir) do
    unsafe =
      for {raw, _name} <- rows, raw == "" or Path.basename(raw) != raw do
        "invalid raw file name: #{inspect(raw)}"
      end

    missing =
      for {raw, _name} <- rows,
          raw != "" and Path.basename(raw) == raw,
          not File.regular?(Path.join([workdir, "raw", raw])) do
        "missing raw file: #{raw}"
      end

    invalid =
      for {raw, name} <- rows, not Regex.match?(@name_pattern, name) do
        "invalid avatar name: #{inspect(name)} (raw: #{raw})"
      end

    duplicates =
      rows
      |> Enum.frequencies_by(fn {_raw, name} -> name end)
      |> Enum.filter(fn {_name, count} -> count > 1 end)
      |> Enum.map(fn {name, _count} -> "duplicate avatar name: #{name}" end)

    unsafe ++ missing ++ invalid ++ duplicates
  end

  ## naming sheet

  defp render_index(sections) do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <title>sprite naming sheet</title>
    <style>
    body { margin: 0; background: #16181d; color: #d5d8de; font-family: monospace; }
    header { position: fixed; top: 0; left: 0; right: 0; display: flex; gap: 1rem;
      align-items: center; padding: 0.6rem 1rem; background: #22252c;
      border-bottom: 1px solid #333842; }
    main { padding: 4rem 1rem 2rem; }
    h2 { margin: 1.5rem 0 0.5rem; }
    .grid { display: flex; flex-wrap: wrap; gap: 0.5rem; }
    .card { margin: 0; padding: 0.4rem; width: 96px; text-align: center;
      background: #1d2026; border: 1px solid #2a2e36; }
    figcaption { font-size: 10px; color: #8a8f99; margin: 0.3rem 0; overflow-wrap: anywhere; }
    input { width: 100%; box-sizing: border-box; background: #12141a; color: #d5d8de;
      border: 1px solid #333842; padding: 0.2rem; font-family: inherit; }
    button { background: #2d5a3d; color: #d5d8de; border: none; padding: 0.4rem 0.8rem;
      cursor: pointer; font-family: inherit; }
    </style>
    </head>
    <body>
    <header>
    <strong id="count">named: 0</strong>
    <button id="download">download names.csv</button>
    </header>
    <main>
    #{Enum.map_join(sections, "\n", &section_html/1)}
    </main>
    <script>
    const inputs = [...document.querySelectorAll("input[data-raw]")];
    const count = document.getElementById("count");

    const refresh = () => {
      const named = inputs.filter((input) => input.value.trim() !== "").length;
      count.textContent = "named: " + named;
    };

    inputs.forEach((input) => {
      input.value = localStorage.getItem(input.dataset.raw) || "";
      input.addEventListener("input", () => {
        localStorage.setItem(input.dataset.raw, input.value);
        refresh();
      });
    });
    refresh();

    document.getElementById("download").addEventListener("click", () => {
      const lines = inputs
        .filter((input) => input.value.trim() !== "")
        .map((input) => input.dataset.raw + "," + input.value.trim().toLowerCase());
      const blob = new Blob([lines.join("\\n") + "\\n"], { type: "text/csv" });
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = "names.csv";
      link.click();
      URL.revokeObjectURL(link.href);
    });
    </script>
    </body>
    </html>
    """
  end

  defp section_html({prefix, files}) do
    """
    <section>
    <h2>#{prefix} — #{length(files)} tiles</h2>
    <div class="grid">
    #{Enum.map_join(files, "\n", &card_html/1)}
    </div>
    </section>
    """
  end

  defp card_html(file) do
    """
    <figure class="card">
    <img src="raw/#{file}" width="48" height="48" style="image-rendering: pixelated" alt="#{file}">
    <figcaption>#{file}</figcaption>
    <input data-raw="#{file}" spellcheck="false" placeholder="avatar name">
    </figure>
    """
  end
end
