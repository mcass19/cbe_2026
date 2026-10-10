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
            # How many of the newest feed messages are scrolled out of
            # view below; 0 means pinned to the newest. Driven by the
            # seated up/down keys, consumed by `Render`.
            feed_scroll: 0,
            seated?: false,
            # How far the stage curtain has drawn back, 0 (shut) to
            # `Theatre.curtain_steps/0` (wide open). Animated by
            # `LobbyTui.Theatre`, consumed by `Render`; sitting drives it
            # up, standing drives it back down.
            curtain: 0,
            # The "now showing" sign (an `Ascii` marquee) that plays on an
            # open stage until the feed has its first message: the
            # animation, the time it has played to, and its latest frame.
            # Driven by `LobbyTui.Theatre`, painted by `Render`.
            marquee: nil,
            marquee_t: 0.0,
            marquee_frame: nil,
            hint: nil,
            connected?: false,
            refresh_pending?: false,
            allow_quit?: false

  @doc """
  Builds fresh state at the spawn point. `avatar_cache` is the boot-static
  `%{avatar_id => %{cells:, color:, top_trim:}}` map (plus a `:fallback`
  entry) built once by `LobbyTui.Theatre` at mount and consulted by the
  render compositor; it defaults to empty for callers that do not render
  sprites.
  """
  def new(attendee, color, avatar_cache \\ %{}) do
    %__MODULE__{
      attendee: attendee,
      pos: World.spawn_point(),
      color: color,
      avatar_cache: avatar_cache
    }
  end

  @doc """
  Leafs through the feed history by `delta` (positive toward older
  messages), clamped so the view can neither scroll past the oldest
  message nor below the newest. `visible` is how many feed lines the
  stage shows at once — the caller reads it from `Render`, keeping this
  transition pure.
  """
  def scroll_feed(%__MODULE__{} = state, delta, visible) do
    max_scroll = max(length(state.feed) - visible, 0)
    %{state | feed_scroll: (state.feed_scroll + delta) |> max(0) |> min(max_scroll)}
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
