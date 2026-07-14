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
    state = State.new(attendee, color)

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

  def handle_event(_event, state), do: {:noreply, state}

  @impl true
  def handle_info({:say, body}, state), do: {:noreply, say(state, body)}

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, state) do
    {:noreply, %{state | others: LobbyTui.Presence.others(state.attendee.id)}}
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
      {:error, %Ash.Error.Forbidden{}} -> State.hint(state, "slow down — 6 messages/min")
      {:error, _invalid} -> State.hint(state, "message must be 1–200 chars")
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

    %{
      state
      | connected?: true,
        others: LobbyTui.Presence.others(state.attendee.id),
        occupied: occupied
    }
  end

  defp broadcast_position(%State{connected?: true} = state) do
    {:ok, _ref} = LobbyTui.Presence.move(state)
    state
  end

  defp broadcast_position(state), do: state
end
