defmodule LobbyTui.SpriteLoader do
  @moduledoc """
  Boot-time sprite pipeline: decodes every PNG in `priv/sprites_src/`, converts to half-block cells via `Converter`, and seeds the Avatar resource. Runs once in `init/1` and then idles; the render hot path never opens a file. A built-in `unknown` avatar is always seeded so a decode failure can never leave the room without a fallback sprite.
  """

  use GenServer

  require Logger

  alias LobbyTui.SpriteLoader.Converter

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    load_all!()
    {:ok, %{}}
  end

  def load_all! do
    seed_unknown!()

    sprites_dir()
    |> Path.join("*.png")
    |> Path.wildcard()
    |> Enum.each(&load_file/1)
  end

  defp load_file(path) do
    name = Path.basename(path, ".png")

    case decode(path) do
      {:ok, pixels} ->
        LobbyTui.Lobby.seed_avatar!(%{
          name: name,
          sprite_cells: Converter.to_cells(pixels),
          dominant_color: Converter.dominant_color(pixels),
          license: "CC0",
          attribution: "see docs/ATTRIBUTION.md"
        })

      {:error, reason} ->
        Logger.warning("SpriteLoader: skipping #{Path.basename(path)}: #{inspect(reason)}")
    end
  end

  # The one ExPng-touching function. Returns rows of {r, g, b, a} tuples.
  defp decode(path) do
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

  defp seed_unknown! do
    gray = {128, 128, 128, 255}
    pixels = for _ <- 1..4, do: for(_ <- 1..4, do: gray)

    LobbyTui.Lobby.seed_avatar!(%{
      name: "unknown",
      sprite_cells: Converter.to_cells(pixels),
      dominant_color: Converter.dominant_color(pixels),
      license: "CC0",
      attribution: "built-in fallback"
    })
  end

  defp sprites_dir do
    Application.get_env(:lobby_tui, :sprites_dir) ||
      Path.join(:code.priv_dir(:lobby_tui), "sprites_src")
  end
end
