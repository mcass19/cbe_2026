defmodule LobbyTui.Presence do
  @moduledoc """
  Presence over `LobbyTui.PubSub`: one entry per attendee on `"lobby:presence"`, meta `%{nickname, color, avatar_id, x, y}`. This is the fast lane — positions update here on every step and never touch Ash.
  """

  use Phoenix.Presence, otp_app: :lobby_tui, pubsub_server: LobbyTui.PubSub

  @topic "lobby:presence"

  def topic, do: @topic

  def track_attendee(state), do: track(self(), @topic, state.attendee.id, meta(state))

  def move(state), do: update(self(), @topic, state.attendee.id, meta(state))

  defp meta(state) do
    {x, y} = state.pos

    %{
      nickname: state.attendee.nickname,
      color: state.color,
      avatar_id: state.attendee.avatar_id,
      x: x,
      y: y
    }
  end

  @doc """
  Everyone on the topic but `attendee_id`, as `%{id => %{nickname, color, avatar_id, x, y}}`.

  Read straight from the tracker shard's ETS table rather than through `list/1`: `list/1` is a `GenServer.call` to the one shard process that also serializes every `track`/`update`, so with a full room every viewer's refresh queued behind everyone's steps, and a call that waited past 5 s crashed the viewer's TUI. The table can be a beat behind the shard, which a redraw every 200 ms never notices.
  """
  def others(attendee_id) do
    for {id, meta} <- entries(), id != attendee_id, into: %{} do
      {id, Map.take(meta, [:nickname, :color, :avatar_id, :x, :y])}
    end
  end

  @doc "The attendee's presence meta, read like `others/1`, or `nil` when they're not here."
  def meta_of(attendee_id) do
    Enum.find_value(entries(), fn {id, meta} -> if id == attendee_id, do: meta end)
  end

  defp entries, do: Phoenix.Tracker.Shard.dirty_list(shard(), @topic)

  # Phoenix.Tracker shards a tracker by topic; the pool size lives in the
  # tracker's own table.
  defp shard do
    [{:pool_size, size}] = :ets.lookup(__MODULE__, :pool_size)
    Phoenix.Tracker.Shard.name_for_topic(__MODULE__, @topic, size)
  end
end
