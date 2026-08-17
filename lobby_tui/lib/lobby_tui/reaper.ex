defmodule LobbyTui.Reaper do
  @moduledoc """
  Grace-period cleanup. Watches presence diffs; when an attendee's last connection leaves, schedules `Lobby.leave` after the grace period (default 30 s — long enough to survive a phone lock or a refresh) and cancels the timer if they come back first.

  Phoenix Presence emits the same id in both `joins` and `leaves` of a single `presence_diff` whenever tracked metadata is updated (this happens on every movement step, since `Theatre.broadcast_position/1` updates Presence metadata as an attendee moves). That is a metadata update, not a departure, so ids present in both are excluded from scheduling — only ids that left without also rejoining in the same diff get a reap timer.
  """

  use GenServer

  @default_grace :timer.seconds(30)

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    Phoenix.PubSub.subscribe(LobbyTui.PubSub, LobbyTui.Presence.topic())
    {:ok, %{grace: Keyword.get(opts, :grace_ms, @default_grace), timers: %{}}}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: payload}, state) do
    join_ids = Map.keys(payload.joins)
    leave_ids = Map.keys(payload.leaves)

    state =
      state
      |> cancel_reaps(join_ids)
      |> schedule_reaps(leave_ids -- join_ids)

    {:noreply, state}
  end

  def handle_info({:reap, attendee_id}, state) do
    # An id can carry two Presence metas at once (longpoll→websocket swap, a
    # second tab) — closing one connection alone emits the id in `leaves`
    # while a meta is still tracked, scheduling a reap for an attendee who
    # is, in fact, still connected. Re-check Presence directly (not just the
    # timers map, which only tracks scheduling) immediately before reaping.
    if Map.has_key?(state.timers, attendee_id) and
         not Map.has_key?(LobbyTui.Presence.list(LobbyTui.Presence.topic()), attendee_id) do
      case LobbyTui.Lobby.get_attendee(attendee_id) do
        {:ok, attendee} -> LobbyTui.Lobby.leave(attendee)
        {:error, _already_gone} -> :ok
      end
    end

    {:noreply, %{state | timers: Map.delete(state.timers, attendee_id)}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # An id can leave twice with no join between — one attendee, two tabs,
  # closed a while apart. Scheduling over the top of a live timer would
  # leave the first one armed but unreachable: it fires at the *first*
  # leave's deadline, finds the second timer's entry in the map, and reaps
  # early. Cancel before re-arming so the grace period is always measured
  # from the most recent disconnect.
  defp schedule_reaps(state, ids) do
    Enum.reduce(ids, state, fn id, acc ->
      acc = cancel_reaps(acc, [id])
      timer = Process.send_after(self(), {:reap, id}, acc.grace)
      %{acc | timers: Map.put(acc.timers, id, timer)}
    end)
  end

  defp cancel_reaps(state, ids) do
    Enum.reduce(ids, state, fn id, acc ->
      case Map.pop(acc.timers, id) do
        {nil, timers} ->
          %{acc | timers: timers}

        {timer, timers} ->
          _ = Process.cancel_timer(timer)
          %{acc | timers: timers}
      end
    end)
  end
end
