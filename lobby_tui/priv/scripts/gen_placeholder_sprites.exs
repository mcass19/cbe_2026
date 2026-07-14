# Generates the placeholder avatar set and the converter test fixture.
# Run once: mix run priv/scripts/gen_placeholder_sprites.exs
palette = [
  {"crimson", {220, 60, 60}},
  {"ember", {230, 130, 40}},
  {"gold", {230, 200, 60}},
  {"moss", {90, 180, 80}},
  {"teal", {60, 190, 180}},
  {"sky", {80, 140, 230}},
  {"violet", {150, 90, 220}},
  {"rose", {230, 100, 170}}
]

body = fn {r, g, b} ->
  for y <- 0..11 do
    for x <- 0..11 do
      cond do
        y in 2..11 and x in 2..9 and not (y == 5 and x in [4, 7]) -> {r, g, b, 255}
        y == 5 and x in [4, 7] -> {20, 20, 20, 255}
        true -> {0, 0, 0, 0}
      end
    end
  end
end

dest_dir = Path.join([:code.priv_dir(:lobby_tui), "sprites_src"])
File.mkdir_p!(dest_dir)

Enum.each(palette, fn {name, color} ->
  pixels =
    color
    |> body.()
    |> Enum.map(fn row ->
      Enum.map(row, fn {r, g, b, a} -> ExPng.Color.rgba(r, g, b, a) end)
    end)

  image = ExPng.Image.new(pixels)
  path = Path.join(dest_dir, "#{name}.png")
  {:ok, ^path} = ExPng.Image.to_file(image, path)
  IO.puts("wrote #{path}")
end)
