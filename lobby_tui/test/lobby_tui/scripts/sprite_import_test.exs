defmodule LobbyTui.Scripts.SpriteImportTest do
  use ExUnit.Case, async: true

  alias LobbyTui.Scripts.SpriteImport
  alias LobbyTui.SpriteLoader.Png

  @moduletag :tmp_dir

  @red {255, 0, 0, 255}
  @blue {0, 0, 255, 255}
  @ghost {0, 255, 0, 100}
  @clear {0, 0, 0, 0}

  describe "extract/2 from a spritesheet" do
    test "drops transparent cells, thresholds alpha, and center-crops to 12x12", %{tmp_dir: tmp} do
      # 32x16 sheet = two 16x16 cells. Cell 0 is fully transparent; cell 1
      # holds an opaque 4x4 red block at local (6..9, 6..9) surrounded by a
      # ring of alpha-100 pixels at local (5..10, 5..10).
      sheet = Path.join(tmp, "sheet.png")

      write_png!(
        sheet,
        grid(32, 16, fn
          x, y when x in 22..25 and y in 6..9 -> @red
          x, y when x in 21..26 and y in 5..10 -> @ghost
          _x, _y -> @clear
        end)
      )

      work = Path.join(tmp, "work")
      result = SpriteImport.extract([{"onebit", sheet}], work)

      assert result.counts == [{"onebit", 1}]
      assert File.ls!(Path.join(work, "raw")) == ["onebit_0001.png"]

      {:ok, rows} = Png.decode(Path.join([work, "raw", "onebit_0001.png"]))

      # Center crop drops 2 px per edge: the block lands at (4..7, 4..7) and
      # every alpha-100 ring pixel became fully transparent.
      assert rows ==
               grid(12, 12, fn
                 x, y when x in 4..7 and y in 4..7 -> @red
                 _x, _y -> @clear
               end)
    end

    test "alpha 128 stays opaque while 127 goes transparent", %{tmp_dir: tmp} do
      sheet = Path.join(tmp, "sheet.png")

      write_png!(
        sheet,
        grid(16, 16, fn
          5, 5 -> {10, 20, 30, 128}
          6, 5 -> {10, 20, 30, 127}
          _x, _y -> @clear
        end)
      )

      work = Path.join(tmp, "work")
      SpriteImport.extract([{"edge", sheet}], work)

      {:ok, rows} = Png.decode(Path.join([work, "raw", "edge_0000.png"]))

      # Crop shifts by 2: (5, 5) lands at (3, 3) with alpha snapped to 255;
      # the alpha-127 neighbor cleared entirely.
      assert rows ==
               grid(12, 12, fn
                 3, 3 -> {10, 20, 30, 255}
                 _x, _y -> @clear
               end)
    end

    test "slices multi-band sheets row-major", %{tmp_dir: tmp} do
      sheet = Path.join(tmp, "sheet.png")

      cell_colors = %{
        {0, 0} => {201, 0, 0, 255},
        {1, 0} => {0, 202, 0, 255},
        {0, 1} => {0, 0, 203, 255},
        {1, 1} => {204, 204, 0, 255}
      }

      write_png!(sheet, grid(32, 32, fn x, y -> cell_colors[{div(x, 16), div(y, 16)}] end))

      work = Path.join(tmp, "work")
      result = SpriteImport.extract([{"quad", sheet}], work)

      assert result.counts == [{"quad", 4}]

      # Row-major: 0 and 1 are the top band left-to-right, 2 and 3 the bottom.
      for {index, key} <- [{0, {0, 0}}, {1, {1, 0}}, {2, {0, 1}}, {3, {1, 1}}] do
        {:ok, rows} = Png.decode(Path.join([work, "raw", "quad_000#{index}.png"]))
        assert rows == grid(12, 12, fn _x, _y -> cell_colors[key] end)
      end
    end

    test "rejects a prefix outside the closed character set", %{tmp_dir: tmp} do
      sheet = Path.join(tmp, "sheet.png")
      write_png!(sheet, grid(16, 16, fn _x, _y -> @red end))

      assert_raise ArgumentError, ~r/invalid prefix/, fn ->
        SpriteImport.extract([{"../evil", sheet}], Path.join(tmp, "work"))
      end
    end

    test "ignores the ragged remainder of a sheet that does not divide by 16", %{tmp_dir: tmp} do
      sheet = Path.join(tmp, "sheet.png")
      write_png!(sheet, grid(20, 20, fn _x, _y -> {1, 2, 3, 255} end))

      work = Path.join(tmp, "work")
      result = SpriteImport.extract([{"rag", sheet}], work)

      assert result.counts == [{"rag", 1}]
      assert File.ls!(Path.join(work, "raw")) == ["rag_0000.png"]
    end
  end

  describe "extract/2 from a directory" do
    test "center-pads small tiles to 12x12 and numbers from trailing digits", %{tmp_dir: tmp} do
      src = Path.join(tmp, "tiles")
      File.mkdir_p!(src)

      # 8x8 tile with an opaque 2x2 block at (3..4, 3..4); trailing digits in
      # the filename pin the raw number.
      write_png!(
        Path.join(src, "hero_0007.png"),
        grid(8, 8, fn
          x, y when x in 3..4 and y in 3..4 -> @blue
          _x, _y -> @clear
        end)
      )

      # 1x1 opaque tile without trailing digits falls back to its file index.
      write_png!(Path.join(src, "blob.png"), [[{9, 9, 9, 255}]])

      work = Path.join(tmp, "work")
      result = SpriteImport.extract([{"tiny", src}], work)

      assert result.counts == [{"tiny", 2}]
      assert Enum.sort(File.ls!(Path.join(work, "raw"))) == ["tiny_0000.png", "tiny_0007.png"]

      # Padding offset is div(12 - 8, 2) = 2 per leading edge: block at (5..6, 5..6).
      {:ok, hero} = Png.decode(Path.join([work, "raw", "tiny_0007.png"]))

      assert hero ==
               grid(12, 12, fn
                 x, y when x in 5..6 and y in 5..6 -> @blue
                 _x, _y -> @clear
               end)

      # 1x1 pads to div(12 - 1, 2) = 5 on each leading edge.
      {:ok, blob} = Png.decode(Path.join([work, "raw", "tiny_0000.png"]))

      assert blob ==
               grid(12, 12, fn
                 5, 5 -> {9, 9, 9, 255}
                 _x, _y -> @clear
               end)
    end

    test "colliding trailing digits fall back to the lowest free number", %{tmp_dir: tmp} do
      src = Path.join(tmp, "tiles")
      File.mkdir_p!(src)

      write_png!(Path.join(src, "a_1.png"), [[@red]])
      write_png!(Path.join(src, "b_0001.png"), [[@blue]])

      work = Path.join(tmp, "work")
      result = SpriteImport.extract([{"c", src}], work)

      assert result.counts == [{"c", 2}]
      assert Enum.sort(File.ls!(Path.join(work, "raw"))) == ["c_0000.png", "c_0001.png"]

      # Sorted file order: a_1.png claims 0001 first, so b_0001.png falls
      # back to 0000 instead of silently overwriting it.
      {:ok, kept} = Png.decode(Path.join([work, "raw", "c_0001.png"]))

      assert kept ==
               grid(12, 12, fn
                 5, 5 -> @red
                 _x, _y -> @clear
               end)
    end
  end

  describe "extract/2 naming sheet" do
    test "writes an index.html with a section per prefix and a card per tile", %{tmp_dir: tmp} do
      sheet = Path.join(tmp, "sheet.png")
      write_png!(sheet, grid(16, 16, fn _x, _y -> @red end))

      src = Path.join(tmp, "tiles")
      File.mkdir_p!(src)
      write_png!(Path.join(src, "z_0003.png"), grid(12, 12, fn _x, _y -> @blue end))

      work = Path.join(tmp, "work")
      result = SpriteImport.extract([{"a", sheet}, {"b", src}], work)

      assert result.counts == [{"a", 1}, {"b", 1}]
      assert result.index_html == Path.join(work, "index.html")

      html = File.read!(result.index_html)

      assert html =~ "<h2>a — 1 tiles</h2>"
      assert html =~ "<h2>b — 1 tiles</h2>"
      assert html =~ ~s(<img src="raw/a_0000.png")
      assert html =~ ~s(<input data-raw="a_0000.png")
      assert html =~ ~s(<img src="raw/b_0003.png")
      assert html =~ ~s(<input data-raw="b_0003.png")
      assert html =~ "localStorage"
      assert html =~ "names.csv"
    end
  end

  describe "apply/3" do
    test "copies validated rows into dest as <avatar_name>.png", %{tmp_dir: tmp} do
      work = Path.join(tmp, "work")
      raw = Path.join(work, "raw")
      File.mkdir_p!(raw)
      File.write!(Path.join(raw, "a_0000.png"), "png-a")
      File.write!(Path.join(raw, "b_0001.png"), "png-b")

      csv = Path.join(tmp, "names.csv")

      File.write!(csv, """
      a_0000.png, Crimson.PNG

      b_0001.png,moss-2
      """)

      dest = Path.join(tmp, "dest")

      assert SpriteImport.apply(csv, work, dest) == {:ok, 2}
      assert File.read!(Path.join(dest, "crimson.png")) == "png-a"
      assert File.read!(Path.join(dest, "moss-2.png")) == "png-b"
    end

    test "reports every violation together and copies nothing", %{tmp_dir: tmp} do
      work = Path.join(tmp, "work")
      raw = Path.join(work, "raw")
      File.mkdir_p!(raw)
      File.write!(Path.join(raw, "a_0000.png"), "png-a")

      csv = Path.join(tmp, "names.csv")

      File.write!(csv, """
      missing.png,ghost
      a_0000.png,Bad Name
      a_0000.png,-lead
      a_0000.png,dup
      a_0000.png,dup
      nocomma
      """)

      dest = Path.join(tmp, "dest")

      assert {:error, reasons} = SpriteImport.apply(csv, work, dest)

      assert "missing raw file: missing.png" in reasons
      assert ~s{invalid avatar name: "bad name" (raw: a_0000.png)} in reasons
      assert ~s{invalid avatar name: "-lead" (raw: a_0000.png)} in reasons
      assert "duplicate avatar name: dup" in reasons
      assert "missing raw file: nocomma" in reasons
      assert ~s{invalid avatar name: "" (raw: nocomma)} in reasons

      refute File.dir?(dest)
    end

    test "rejects raw names containing path separators", %{tmp_dir: tmp} do
      work = Path.join(tmp, "work")
      File.mkdir_p!(Path.join(work, "raw"))

      # The file exists one level above raw/ — the guard must reject the row
      # anyway, by shape, not by existence.
      File.write!(Path.join(tmp, "outside.png"), "outside")

      csv = Path.join(tmp, "names.csv")
      File.write!(csv, "../outside.png,sneaky\n,empty\n")

      dest = Path.join(tmp, "dest")

      assert {:error, reasons} = SpriteImport.apply(csv, work, dest)
      assert ~s{invalid raw file name: "../outside.png"} in reasons
      assert ~s{invalid raw file name: ""} in reasons
      refute File.dir?(dest)
    end

    test "defaults dest to priv/sprites_src without copying on invalid input", %{tmp_dir: tmp} do
      work = Path.join(tmp, "work")
      File.mkdir_p!(Path.join(work, "raw"))

      csv = Path.join(tmp, "names.csv")
      File.write!(csv, "missing.png,ghost\n")

      assert String.ends_with?(SpriteImport.default_dest(), "sprites_src")
      before = Enum.sort(File.ls!(SpriteImport.default_dest()))

      assert SpriteImport.apply(csv, work) == {:error, ["missing raw file: missing.png"]}
      assert Enum.sort(File.ls!(SpriteImport.default_dest())) == before
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
