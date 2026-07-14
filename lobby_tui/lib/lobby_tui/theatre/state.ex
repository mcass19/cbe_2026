defmodule LobbyTui.Theatre.State do
  @moduledoc """
  The Theatre's in-process state: who we are, where we stand, everyone else's last known position (from Presence), seat occupancy, and the stage feed. Purely data plus pure transitions — every side effect (Ash calls, Presence updates) lives in `LobbyTui.Theatre`.
  """

  alias LobbyTui.World

  defstruct attendee: nil,
            pos: {0, 0},
            color: nil,
            others: %{},
            occupied: %{},
            feed: [],
            seated?: false,
            hint: nil,
            connected?: false

  def new(attendee, color) do
    %__MODULE__{attendee: attendee, pos: World.spawn_point(), color: color}
  end

  def step(%__MODULE__{pos: {x, y}} = state, direction) do
    target =
      case direction do
        :up -> {x, y - 1}
        :down -> {x, y + 1}
        :left -> {x - 1, y}
        :right -> {x + 1, y}
      end

    if World.walkable?(target) and not occupied_by_other?(state, target) do
      %{state | pos: target, hint: nil}
    else
      state
    end
  end

  def hint(state, text), do: %{state | hint: text}

  defp occupied_by_other?(%__MODULE__{others: others}, {tx, ty}) do
    Enum.any?(others, fn {_id, %{x: x, y: y}} -> x == tx and y == ty end)
  end
end
