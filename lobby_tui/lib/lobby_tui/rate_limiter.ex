defmodule LobbyTui.RateLimiter do
  @moduledoc """
  A per-attendee message counter backed by an ETS table: 6 messages per attendee per rolling 60-second window. `within_limit?/2` counts the attempt and reports whether it is still inside the window; a refused attempt is still counted, deliberately, so hammering the limit stays unprofitable. Each attendee's window is anchored at their first attempt after the previous window expired (not aligned to an absolute clock grid), so a burst is always judged against a full 60 seconds from its own start. Old entries are left behind; the table is wiped with the room on restart, which is all the cleanup a one-day event needs.
  """

  use GenServer

  @table :lobby_tui_rate_limiter
  @limit 6
  @window_seconds 60

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    {:ok, %{}}
  end

  def within_limit?(attendee_id, now_seconds \\ System.system_time(:second)) do
    GenServer.call(__MODULE__, {:attempt, attendee_id, now_seconds})
  end

  @impl true
  def handle_call({:attempt, attendee_id, now_seconds}, _from, state) do
    within_limit? =
      case :ets.lookup(@table, attendee_id) do
        [{^attendee_id, window_start, count}] when now_seconds - window_start < @window_seconds ->
          new_count = count + 1
          :ets.insert(@table, {attendee_id, window_start, new_count})
          new_count <= @limit

        _ ->
          :ets.insert(@table, {attendee_id, now_seconds, 1})
          true
      end

    {:reply, within_limit?, state}
  end
end
