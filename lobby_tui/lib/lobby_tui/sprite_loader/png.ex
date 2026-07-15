defmodule LobbyTui.SpriteLoader.Png do
  @moduledoc """
  The one ExPng-touching module. Decodes a PNG file into rows of `{r, g, b, a}` pixel tuples — the shape `SpriteLoader.Converter.to_cells/1` expects. Shared by `SpriteLoader` (avatar sprites) and `Scene` (the theatre background), so the ExPng dependency stays isolated to a single place.
  """

  def decode(path) do
    case ExPng.Image.from_file(path) do
      {:ok, image} -> {:ok, pixel_rows(image)}
      {:error, _, _} = error -> {:error, error}
      {:error, _} = error -> error
    end
  end

  defp pixel_rows(image) do
    # ExPng decodes every color mode into a canvas of 4-byte binaries
    # (<<r, g, b, a>>), one per pixel, regardless of the source PNG's bit
    # depth or color type. Normalize each to an {r, g, b, a} tuple.
    Enum.map(image.pixels, fn row ->
      Enum.map(row, fn <<r, g, b, a>> -> {r, g, b, a} end)
    end)
  end
end
