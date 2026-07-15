defmodule LobbyTui.Scene do
  @moduledoc """
  Boot-time theatre background loader: decodes `priv/scene/theatre.png`
  into half-block cells via `SpriteLoader.Converter` and stores them in
  `:persistent_term` under a write-once, read-heavy key — ideal for the
  render hot path, which never touches a file. A missing or corrupt PNG
  never fails boot: it logs a warning and stores an empty scene, and
  `Scene.cell/1` returning `nil` is the same signal the render path already
  treats as bare floor.
  """

  use GenServer

  require Logger

  alias LobbyTui.SpriteLoader.{Converter, Png}

  @persistent_key {__MODULE__, :cells}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    load!()
    {:ok, %{}}
  end

  @doc "Decodes the configured scene PNG and (re)populates the persistent cell store."
  def load! do
    case scene_path() |> Png.decode() do
      {:ok, pixels} ->
        cells = pixels |> Converter.to_cells() |> index_by_pos()
        :persistent_term.put(@persistent_key, cells)

      {:error, reason} ->
        Logger.warning("Scene: failed to load #{scene_path()}: #{inspect(reason)}")
        :persistent_term.put(@persistent_key, %{})
    end

    :ok
  end

  @doc "The `{char, fg, bg}` cell at `{col, row}`, or nil off-scene or before load."
  def cell(pos), do: cells() |> Map.get(pos)

  @doc "Whether the scene loaded at least one cell."
  def loaded?, do: map_size(cells()) > 0

  defp cells, do: :persistent_term.get(@persistent_key, %{})

  defp index_by_pos(rows) do
    for {row, y} <- Enum.with_index(rows),
        {cell, x} <- Enum.with_index(row),
        into: %{} do
      {{x, y}, cell}
    end
  end

  defp scene_path do
    Application.get_env(:lobby_tui, :scene_path) ||
      Path.join(:code.priv_dir(:lobby_tui), "scene/theatre.png")
  end
end
