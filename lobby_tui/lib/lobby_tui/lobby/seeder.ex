defmodule LobbyTui.Lobby.Seeder do
  @moduledoc """
  Boot-time seed of the static Seat layout from `LobbyTui.World`. Upserts on the `{row, col}` identity, so repeated boots (and repeated test setups) are idempotent.
  """

  def seed_seats! do
    Enum.each(LobbyTui.World.seats(), fn seat ->
      LobbyTui.Lobby.seed_seat!(Map.take(seat, [:row, :col, :x, :y]))
    end)
  end
end
