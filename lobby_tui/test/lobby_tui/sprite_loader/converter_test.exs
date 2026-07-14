defmodule LobbyTui.SpriteLoader.ConverterTest do
  use ExUnit.Case, async: true

  alias LobbyTui.SpriteLoader.Converter

  @red {255, 0, 0, 255}
  @blue {0, 0, 255, 255}
  @clear {0, 0, 0, 0}

  test "two pixel rows fold into one half-block cell row" do
    pixels = [
      [@red, @clear],
      [@blue, @clear]
    ]

    assert Converter.to_cells(pixels) == [
             [
               {"▀", {:rgb, 255, 0, 0}, {:rgb, 0, 0, 255}},
               {" ", nil, nil}
             ]
           ]
  end

  test "top-only and bottom-only pixels pick the matching half block" do
    assert Converter.to_cells([[@red], [@clear]]) == [[{"▀", {:rgb, 255, 0, 0}, nil}]]
    assert Converter.to_cells([[@clear], [@blue]]) == [[{"▄", {:rgb, 0, 0, 255}, nil}]]
  end

  test "odd row counts pad the missing bottom row as transparent" do
    assert Converter.to_cells([[@red]]) == [[{"▀", {:rgb, 255, 0, 0}, nil}]]
  end

  test "dominant color is the most frequent opaque pixel" do
    pixels = [[@red, @red], [@blue, @clear]]
    assert Converter.dominant_color(pixels) == {:rgb, 255, 0, 0}
  end

  test "dominant color of a fully transparent sprite falls back to gray" do
    assert Converter.dominant_color([[@clear]]) == {:rgb, 128, 128, 128}
  end

  test "alpha 128 is opaque, 127 is transparent" do
    at_threshold = {10, 20, 30, 128}
    below = {10, 20, 30, 127}
    assert Converter.to_cells([[at_threshold], [below]]) == [[{"▀", {:rgb, 10, 20, 30}, nil}]]
  end
end
