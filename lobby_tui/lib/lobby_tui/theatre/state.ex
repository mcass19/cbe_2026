defmodule LobbyTui.Theatre.State do
  @moduledoc """
  The Theatre's in-process state: who we are, where we stand, everyone else's last known position (from Presence, indexed by cell for O(1) lookups), seat occupancy, the boot-static avatar sprite cache, and the stage feed. Purely data plus pure transitions — every side effect (Ash calls, Presence updates) lives in `LobbyTui.Theatre`.
  """

  alias LobbyTui.World

  defstruct attendee: nil,
            pos: {0, 0},
            color: nil,
            avatar_cache: %{},
            others_by_pos: %{},
            occupied: %{},
            feed: [],
            seated?: false,
            hint: nil,
            connected?: false,
            refresh_pending?: false,
            allow_quit?: false

  @doc """
  Builds fresh state at the spawn point. `avatar_cache` is the boot-static
  `%{avatar_id => %{cells:, color:}}` map (plus a `:fallback` entry) built
  once by `LobbyTui.Theatre` at mount and consulted by the render
  compositor; it defaults to empty for callers that do not render sprites.
  """
  def new(attendee, color, avatar_cache \\ %{}) do
    %__MODULE__{
      attendee: attendee,
      pos: World.spawn_point(),
      color: color,
      avatar_cache: avatar_cache
    }
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

  @doc "Indexes a `%{id => %{x, y, ...}}` presence map by `{x, y}` cell for O(1) render/collision lookups."
  def index_by_pos(others) do
    Map.new(others, fn {_id, other} -> {{other.x, other.y}, other} end)
  end

  defp occupied_by_other?(%__MODULE__{others_by_pos: others_by_pos}, target) do
    Map.has_key?(others_by_pos, target)
  end
end
