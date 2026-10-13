defmodule LobbyTui.Scene do
  @moduledoc """
  Boot-time theatre background loader: decodes `priv/scene/theatre.png`
  into half-block cells via `SpriteLoader.Converter` and stores them in
  `:persistent_term` under a write-once, read-heavy key — ideal for the
  render hot path, which never touches a file. A missing or corrupt PNG
  never fails boot: it logs a warning and stores an empty scene, and
  `Scene.cell/1` returning `nil` is the same signal the render path already
  treats as bare floor.

  It also keeps the render path's cache of finished scene rows (`row/2`):
  a row of the world with nobody drawn over it looks the same for every
  viewer whose camera frames the same columns, so it is built once.
  """

  use GenServer

  require Logger

  alias LobbyTui.SpriteLoader.{Converter, Png}

  @persistent_key {__MODULE__, :cells}
  @rows __MODULE__.Rows

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    :ets.new(@rows, [:named_table, :public, :set, read_concurrency: true])
    load!()
    {:ok, %{}}
  end

  @doc "Decodes the configured scene PNG and (re)populates the persistent cell store."
  def load! do
    case scene_path() |> Png.decode() do
      {:ok, pixels} ->
        pixels |> Converter.to_cells() |> index_by_pos() |> put_cells()

      {:error, reason} ->
        Logger.warning("Scene: failed to load #{scene_path()}: #{inspect(reason)}")
        put_cells(%{})
    end
  end

  @doc "Replaces the scene with `%{{col, row} => {char, fg, bg}}` and drops the cached rows built from the old one."
  def put_cells(cells) do
    :persistent_term.put(@persistent_key, cells)
    if :ets.whereis(@rows) != :undefined, do: :ets.delete_all_objects(@rows)
    :ok
  end

  @doc false
  def cells_snapshot, do: cells()

  @doc "The `{char, fg, bg}` cell at `{col, row}`, or nil off-scene or before load."
  def cell(pos), do: cells() |> Map.get(pos)

  @doc """
  The cached scene row under `key`, built with `build` on first use.

  Keys are the caller's (`Render` uses the row and the visible columns),
  and `load!/0` drops them all. Without the cache table (the Scene server
  not running), it just builds.
  """
  def row(key, build) do
    if :ets.whereis(@rows) == :undefined do
      build.()
    else
      case :ets.lookup(@rows, key) do
        [{^key, row}] ->
          row

        [] ->
          row = build.()
          :ets.insert(@rows, {key, row})
          row
      end
    end
  end

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
