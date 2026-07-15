defmodule LobbyTui.Theatre do
  @moduledoc """
  The one TUI module. Runs unchanged in the browser (via `PhoenixExRatatui.LiveComponent`), a local terminal, and — pass two — SSH. Pure state transitions live in `State`; rendering in `Render`; this module owns the ExRatatui callbacks and the side effects (Ash actions, and once connected, Presence/PubSub).
  """

  @behaviour ExRatatui.App

  alias ExRatatui.Event.Key
  alias LobbyTui.{Lobby, World}
  alias LobbyTui.Theatre.{Render, State}

  @impl true
  def mount(opts) do
    attendee = Keyword.fetch!(opts, :attendee)
    color = avatar_color(attendee)
    state = %{State.new(attendee, color) | allow_quit?: Keyword.get(opts, :quit?, false)}

    state =
      if Keyword.get(opts, :connect?, true) do
        connect(state)
      else
        state
      end

    {:ok, state}
  end

  @impl true
  def render(state, frame), do: Render.widgets(state, frame)

  @impl true
  def handle_event(%Key{code: code, kind: "press"}, state)
      when code in ["up", "down", "left", "right"] do
    {:noreply, state |> State.step(String.to_existing_atom(code)) |> broadcast_position()}
  end

  def handle_event(%Key{code: code, kind: "press"}, state) when code in ["s", "enter"] do
    {:noreply, try_sit(state)}
  end

  # Quit is opt-in via the `quit?: true` mount option (set by `LobbyTui.Local`
  # for the real-terminal transport). The browser embed never passes it, so a
  # stray "q" typed into the room from a browser tab cannot kill the
  # LiveComponent's TUI process.
  def handle_event(%Key{code: "q", kind: "press"}, %State{allow_quit?: true} = state) do
    {:stop, state}
  end

  def handle_event(_event, state), do: {:noreply, state}

  @impl true
  def handle_info({:say, body}, state), do: {:noreply, say(state, body)}

  # Presence diffs arrive at up to one per attendee per movement step, and a
  # naive handler would rebuild the full others index (and trigger a render)
  # on every single one — at ~100 attendees that is hundreds of diffs per
  # second. Coalesce instead: the first diff since the last refresh arms a
  # 100 ms timer; further diffs before it fires are free (state is
  # unchanged, so the runtime's per-message render stays on the cheap,
  # already-indexed render path — see the ex_ratatui render-decision note
  # in the fix-wave report). `:refresh_others` is the only place the index
  # actually rebuilds, bounding rebuilds to at most 10/s regardless of
  # fan-out.
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff"},
        %State{refresh_pending?: true} = state
      ) do
    {:noreply, state}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, state) do
    Process.send_after(self(), :refresh_others, 100)
    {:noreply, %{state | refresh_pending?: true}}
  end

  def handle_info(:refresh_others, state) do
    others = LobbyTui.Presence.others(state.attendee.id)
    {:noreply, %{state | others_by_pos: State.index_by_pos(others), refresh_pending?: false}}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "lobby:seats",
          payload: %Ash.Notifier.Notification{data: seat}
        },
        state
      ) do
    occupied =
      if is_nil(seat.occupant_id) do
        Map.delete(state.occupied, {seat.x, seat.y})
      else
        Map.put(state.occupied, {seat.x, seat.y}, seat.occupant_id)
      end

    {:noreply, %{state | occupied: occupied}}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "lobby:stage",
          payload: %Ash.Notifier.Notification{data: message}
        },
        %State{seated?: true} = state
      ) do
    if Enum.any?(state.feed, &(&1.id == message.id)) do
      {:noreply, state}
    else
      {:noreply, %{state | feed: Enum.take([message | state.feed], 50)}}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "lobby:stage"}, state), do: {:noreply, state}

  def handle_info(_msg, state), do: {:noreply, state}

  # -- side effects ----------------------------------------------------------

  defp try_sit(%State{pos: pos} = state) do
    with %{} = world_seat <- World.seat_at(pos),
         %{} = seat <- find_seat_record(world_seat),
         {:ok, _} <- Lobby.claim_seat(seat, actor: state.attendee) do
      %{state | seated?: true} |> load_feed() |> State.hint(nil)
    else
      nil -> State.hint(state, "walk onto a seat to sit")
      {:error, _taken} -> State.hint(state, "seat taken — try another")
    end
  end

  defp say(%State{seated?: false} = state, _body),
    do: State.hint(state, "take a seat to post")

  defp say(state, body) do
    case Lobby.post_message(body, actor: state.attendee) do
      {:ok, message} -> %{state | feed: Enum.take([message | state.feed], 50)}
      {:error, %Ash.Error.Forbidden{}} -> forbidden_hint(state)
      {:error, _invalid} -> State.hint(state, "message must be 1–200 chars")
    end
  end

  # A Forbidden error from post_message is either the rate limit or a lost
  # seat (reaped, or released from another tab) — re-check which happened
  # so the hint tells the attendee the right thing to do.
  defp forbidden_hint(state) do
    case Lobby.seat_of(state.attendee.id) do
      {:ok, _seat} ->
        State.hint(state, "slow down — 6 messages/min")

      {:error, _unseated} ->
        %{state | seated?: false} |> State.hint("seat lost — sit again to post")
    end
  end

  defp load_feed(state) do
    case Lobby.stage_feed(actor: state.attendee) do
      {:ok, feed} -> %{state | feed: feed}
      {:error, _} -> state
    end
  end

  defp find_seat_record(%{x: x, y: y}) do
    Enum.find(Lobby.list_seats!(), &(&1.x == x and &1.y == y))
  end

  defp avatar_color(attendee) do
    case Lobby.list_avatars!() |> Enum.find(&(&1.id == attendee.avatar_id)) do
      %{dominant_color: color} -> color
      nil -> {:rgb, 128, 128, 128}
    end
  end

  defp connect(state) do
    Phoenix.PubSub.subscribe(LobbyTui.PubSub, LobbyTui.Presence.topic())
    Phoenix.PubSub.subscribe(LobbyTui.PubSub, "lobby:seats")
    Phoenix.PubSub.subscribe(LobbyTui.PubSub, "lobby:stage")
    {:ok, _ref} = LobbyTui.Presence.track_attendee(state)

    occupied =
      Lobby.list_seats!()
      |> Enum.reject(&is_nil(&1.occupant_id))
      |> Map.new(&{{&1.x, &1.y}, &1.occupant_id})

    state = %{
      state
      | connected?: true,
        others_by_pos: State.index_by_pos(LobbyTui.Presence.others(state.attendee.id)),
        occupied: occupied
    }

    # A refresh/reconnect starts a brand-new Theatre state, but the attendee
    # may still be holding a seat in Ash from before the reload — without
    # this check the fresh state comes up unseated while the seat (and any
    # LobbyLive chat form gated on it) says otherwise.
    case Lobby.seat_of(state.attendee.id) do
      {:ok, _seat} -> %{state | seated?: true} |> load_feed()
      {:error, _unseated} -> state
    end
  end

  defp broadcast_position(%State{connected?: true} = state) do
    case LobbyTui.Presence.move(state) do
      {:ok, _ref} -> state
      # A reaped-then-moving edge: the attendee's presence entry is already
      # gone, so there is nothing left to update.
      {:error, _reason} -> state
    end
  end

  defp broadcast_position(state), do: state
end
