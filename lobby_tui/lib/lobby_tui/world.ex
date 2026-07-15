defmodule LobbyTui.World do
  @moduledoc """
  The fixed 176×96 world grid (sprite scale: a 12×12px avatar spans 12 cols × 6 cell rows): border walls, a stage band at the top, ten rows of twelve seats, and an open lobby band at the bottom. Purely static — all functions are deterministic lookups used by `Theatre` (render, movement) and by seat seeding.
  """

  @width 176
  @height 96
  @seats (for row <- 1..10, col <- 1..12 do
            %{row: row, col: col, x: 10 + (col - 1) * 14, y: 18 + (row - 1) * 7}
          end)
  @seat_index Map.new(@seats, &{{&1.x, &1.y}, &1})

  def width, do: @width
  def height, do: @height
  def spawn_point, do: {88, 88}
  def seats, do: @seats

  def seat_at(pos), do: Map.get(@seat_index, pos)

  def tile_at({x, y}) when x in [0, @width - 1] or y in [0, @height - 1], do: :wall

  def tile_at({x, y}) when x > 0 and x < @width - 1 and y > 0 and y < @height - 1 do
    cond do
      y in 2..13 -> :stage
      Map.has_key?(@seat_index, {x, y}) -> :seat
      true -> :floor
    end
  end

  def tile_at(_out_of_bounds), do: :wall

  def walkable?(pos), do: tile_at(pos) in [:floor, :seat]
end
