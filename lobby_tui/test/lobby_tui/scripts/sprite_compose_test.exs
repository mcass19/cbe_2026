defmodule LobbyTui.Scripts.SpriteComposeTest do
  use ExUnit.Case, async: true

  alias LobbyTui.Scripts.SpriteCompose
  alias LobbyTui.SpriteLoader.Png

  @moduletag :tmp_dir

  @red {255, 0, 0, 255}
  @blue {0, 0, 255, 255}
  @clear {0, 0, 0, 0}

  # The real sheet is 918x203: 54x12 cells of 16x16 at a 17px stride.
  @width 918
  @height 203

  describe "run/3" do
    test "slices the sheet at a 17px stride and writes one tile plus csv row per recipe",
         %{tmp_dir: tmp} do
      # Cell {2, 1} spans pixels (34..49, 17..32); paint it solid red and
      # everything else blue so a stride bug would leak blue into the tile.
      sheet = Path.join(tmp, "sheet.png")

      write_png!(
        sheet,
        grid(@width, @height, fn x, y ->
          if x in 34..49 and y in 17..32, do: @red, else: @blue
        end)
      )

      work = Path.join(tmp, "work")
      recipes = [{"gus", {2, 1}, []}]

      assert SpriteCompose.run(sheet, work, recipes) == {:ok, 1}
      assert File.ls!(Path.join(work, "tiles")) == ["villager_0000.png"]

      {:ok, tile} = Png.decode(Path.join([work, "tiles", "villager_0000.png"]))
      assert tile == grid(16, 16, fn _x, _y -> @red end)

      assert File.read!(Path.join(work, "names.csv")) == "villager_0000.png,gus\n"
    end

    test "paints layers over the base in order; layer wins only at alpha >= 128",
         %{tmp_dir: tmp} do
      # Base cell {0, 0} solid red. Layer 1 is cell {1, 0} (pixels 17..32
      # horizontally): one opaque blue pixel at local (0, 0) and one
      # alpha-127 green pixel at local (1, 0). Layer 2 is cell {2, 0}: an
      # opaque white pixel at local (0, 0), overpainting layer 1's blue.
      sheet = Path.join(tmp, "sheet.png")

      write_png!(
        sheet,
        grid(@width, @height, fn
          x, y when x in 0..15 and y in 0..15 -> @red
          17, 0 -> @blue
          18, 0 -> {0, 255, 0, 127}
          34, 0 -> {255, 255, 255, 255}
          _x, _y -> @clear
        end)
      )

      work = Path.join(tmp, "work")
      recipes = [{"mia", {0, 0}, [{1, 0}, {2, 0}]}]

      assert SpriteCompose.run(sheet, work, recipes) == {:ok, 1}

      {:ok, tile} = Png.decode(Path.join([work, "tiles", "villager_0000.png"]))

      # White (layer 2) beat blue (layer 1) at (0, 0); the alpha-127 green
      # never landed, so (1, 0) kept the base red.
      assert tile ==
               grid(16, 16, fn
                 0, 0 -> {255, 255, 255, 255}
                 _x, _y -> @red
               end)
    end
  end

  describe "run/3 validation" do
    test "rejects a sheet with wrong dimensions and writes nothing", %{tmp_dir: tmp} do
      sheet = Path.join(tmp, "sheet.png")
      write_png!(sheet, grid(16, 16, fn _x, _y -> @red end))

      work = Path.join(tmp, "work")

      assert SpriteCompose.run(sheet, work, [{"gus", {0, 0}, []}]) ==
               {:error, ["sheet must be 918x203, got 16x16"]}

      refute File.dir?(work)
    end

    test "reports every recipe violation together and writes nothing", %{tmp_dir: tmp} do
      sheet = Path.join(tmp, "sheet.png")
      write_png!(sheet, grid(@width, @height, fn _x, _y -> @red end))

      work = Path.join(tmp, "work")

      recipes = [
        {"gus", {54, 0}, []},
        {"mia", {0, 12}, [{0, 0}]},
        {"ada", {0, 0}, [{60, 20}]},
        {"Bad Name", {0, 0}, []},
        {"dup", {0, 0}, []},
        {"dup", {1, 0}, []}
      ]

      assert {:error, reasons} = SpriteCompose.run(sheet, work, recipes)

      assert "cell out of range: {54, 0} (recipe: gus)" in reasons
      assert "cell out of range: {0, 12} (recipe: mia)" in reasons
      assert "cell out of range: {60, 20} (recipe: ada)" in reasons
      assert ~s{invalid recipe name: "Bad Name"} in reasons
      assert "duplicate recipe name: dup" in reasons

      refute File.dir?(work)
    end
  end

  defp grid(width, height, fun) do
    for y <- 0..(height - 1), do: for(x <- 0..(width - 1), do: fun.(x, y))
  end

  defp write_png!(path, rows) do
    canvas =
      Enum.map(rows, fn row ->
        Enum.map(row, fn {r, g, b, a} -> ExPng.Color.rgba(r, g, b, a) end)
      end)

    {:ok, ^path} = ExPng.Image.to_file(ExPng.Image.new(canvas), path)
  end
end
