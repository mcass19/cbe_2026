defmodule LobbyTui.SpriteLoader.Converter do
  @moduledoc """
  Pure PNG-pixels-to-cells conversion. Each terminal cell is one pixel wide and two pixels tall: an opaque top pixel over an opaque bottom pixel renders as `▀` with fg = top and bg = bottom; a single opaque half picks `▀` or `▄` with a nil background so the world shows through; fully transparent pairs render as a plain space.
  """

  @alpha_threshold 128
  @fallback_gray {:rgb, 128, 128, 128}

  def to_cells([first_row | _] = pixel_rows) do
    pad = List.duplicate({0, 0, 0, 0}, length(first_row))

    pixel_rows
    |> Enum.chunk_every(2, 2, [pad])
    |> Enum.map(fn [top_row, bottom_row] ->
      Enum.zip_with(top_row, bottom_row, &cell/2)
    end)
  end

  def to_cells([]), do: []

  def dominant_color(pixel_rows) do
    pixel_rows
    |> List.flatten()
    |> Enum.filter(&opaque?/1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_color, count} -> count end, fn -> {nil, 0} end)
    |> case do
      {{r, g, b, _a}, _count} -> {:rgb, r, g, b}
      {nil, 0} -> @fallback_gray
    end
  end

  defp cell(top, bottom) do
    case {opaque?(top), opaque?(bottom)} do
      {true, true} -> {"▀", rgb(top), rgb(bottom)}
      {true, false} -> {"▀", rgb(top), nil}
      {false, true} -> {"▄", rgb(bottom), nil}
      {false, false} -> {" ", nil, nil}
    end
  end

  defp opaque?({_r, _g, _b, a}), do: a >= @alpha_threshold
  defp rgb({r, g, b, _a}), do: {:rgb, r, g, b}
end
