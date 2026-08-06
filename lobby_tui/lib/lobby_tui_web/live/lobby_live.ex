defmodule LobbyTuiWeb.LobbyLive do
  @moduledoc """
  The room page: plain HEEx chrome around the embedded Theatre TUI. The chrome is deliberately HTML — the frame is a web page, the world inside is a terminal.

  The title row and the data-transparency footer come from `LobbyTuiWeb.Layouts.app/1`, shared with the join screen so the two read as one terminal window; this module contributes the leave link, the D-pad and the chat input. The shell overrides the layout's default classes because the room must never scroll — the theatre sizes itself to whatever space the other rows leave.

  There is no written key legend. The pad spells out every action it can perform — arrows, sit, stand — so a row of text repeating them was only taking space away from the room. Situational guidance ("seat taken", "press space to stand") lives in the TUI's own status row, which is the one surface that knows the current state.
  """

  use LobbyTuiWeb, :live_view

  alias LobbyTuiWeb.TheatreComponent

  @impl true
  def mount(_params, session, socket) do
    with attendee_id when is_binary(attendee_id) <- session["attendee_id"],
         {:ok, attendee} <- LobbyTui.Lobby.get_attendee(attendee_id) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(LobbyTui.PubSub, "lobby:seats")
      end

      seated? = match?({:ok, _}, LobbyTui.Lobby.seat_of(attendee.id))
      {:ok, assign(socket, attendee: attendee, seated?: seated?, chat_seq: 0)}
    else
      _missing_or_stale -> {:ok, redirect(socket, to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="reconnect-banner"
      class="fixed top-0 inset-x-0 z-50 hidden bg-[var(--tui-accent)] text-black text-xs text-center py-1"
      phx-disconnected={JS.show(to: "#reconnect-banner")}
      phx-connected={JS.hide(to: "#reconnect-banner")}
    >
      connection lost — reconnecting
    </div>

    <Layouts.app
      flash={@flash}
      id="lobby-shell"
      class="h-dvh overflow-hidden flex flex-col gap-2 p-2"
    >
      <:actions>
        <.link
          id="leave-link"
          href={~p"/leave"}
          method="delete"
          data-confirm="Leave the lobby? This releases your seat and clears your nickname and avatar so you can pick new ones."
          class="text-[var(--tui-accent-2)] hover:underline"
        >
          [leave]
        </.link>
      </:actions>

      <div id="theatre-wrap" class="flex-1 min-h-0 bg-[var(--tui-bg)]">
        <.live_component module={TheatreComponent} id="theatre" attendee={@attendee} />
      </div>

      <form :if={@seated?} id="chat-form" phx-submit="say" class="shrink-0 flex gap-2">
        <div class="flex flex-1 items-center gap-2 border border-[var(--tui-border)] px-2 py-1">
          <span class="text-[var(--tui-accent)]">&gt;</span>
          <input
            id={"chat-input-#{@chat_seq}"}
            name="body"
            type="text"
            maxlength="200"
            autocomplete="off"
            autofocus
            enterkeyhint="send"
            placeholder="say something to the room"
            class="flex-1 border-0 bg-transparent text-[var(--tui-fg)] outline-none placeholder:text-[var(--tui-dim)] caret-[var(--tui-accent)]"
          />
        </div>
        <button
          type="submit"
          class="border border-[var(--tui-border)] px-3 py-1 text-[var(--tui-fg)] hover:border-[var(--tui-accent-2)] hover:text-[var(--tui-accent-2)]"
        >
          send
        </button>
      </form>

      <%!--
        Seated, there is nowhere to walk to — left/right are refused by the
        Theatre and the camera is on the stage anyway — so the pad keeps
        only what still acts: ▲▼ leaf back through the feed playing on the
        stage, and the seat button stands back up.
      --%>
      <div id="d-pad" class="shrink-0 flex justify-center items-end gap-4 select-none">
        <div :if={not @seated?} class="grid grid-cols-3 gap-1">
          <span></span>
          <.pad_button dir="up">▲</.pad_button>
          <span></span>
          <.pad_button dir="left">◄</.pad_button>
          <.pad_button dir="down">▼</.pad_button>
          <.pad_button dir="right">►</.pad_button>
        </div>
        <div :if={@seated?} class="flex gap-1">
          <.pad_button dir="up">▲</.pad_button>
          <.pad_button dir="down">▼</.pad_button>
        </div>
        <.pad_button id="sit-button" dir={if @seated?, do: " ", else: "s"}>
          {if @seated?, do: "stand", else: "sit"}
        </.pad_button>
      </div>
    </Layouts.app>
    """
  end

  # One key of the on-screen pad. `touch-action: manipulation` suppresses
  # the browser's double-tap-to-zoom delay, which otherwise makes repeated
  # taps feel unresponsive — this pad is the only way to move on a phone,
  # and phones are the point.
  attr :dir, :string, required: true
  attr :id, :string, default: nil
  slot :inner_block, required: true

  defp pad_button(assigns) do
    ~H"""
    <button
      id={@id}
      class="min-w-12 min-h-12 p-2 border border-[var(--tui-border)] text-[var(--tui-fg)] active:border-[var(--tui-accent-2)] active:text-[var(--tui-accent-2)]"
      style="touch-action: manipulation;"
      phx-click="dpad"
      phx-value-dir={@dir}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @impl true
  def handle_event("dpad", %{"dir" => dir}, socket)
      when dir in ["up", "down", "left", "right", "s", " "] do
    send_update(TheatreComponent, id: "theatre", tui_input: dir)
    {:noreply, socket}
  end

  def handle_event("say", %{"body" => body}, socket) do
    case String.trim(body) do
      "" ->
        {:noreply, socket}

      trimmed ->
        send_update(TheatreComponent, id: "theatre", tui_say: trimmed)
        # Bumping chat_seq changes the chat input's DOM id, so LiveView
        # mounts a brand-new (empty) input instead of morphing the old one —
        # the simplest way to clear the field after send without a JS hook.
        {:noreply, update(socket, :chat_seq, &(&1 + 1))}
    end
  end

  def handle_event("say", _no_body, socket), do: {:noreply, socket}

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "lobby:seats",
          payload: %Ash.Notifier.Notification{data: seat}
        },
        socket
      ) do
    seated? =
      cond do
        seat.occupant_id == socket.assigns.attendee.id -> true
        is_nil(seat.occupant_id) and not socket.assigns.seated? -> false
        true -> match?({:ok, _}, LobbyTui.Lobby.seat_of(socket.assigns.attendee.id))
      end

    {:noreply, assign(socket, :seated?, seated?)}
  end

  # A plain Phoenix.LiveView parent hosting a PhoenixExRatatui.LiveComponent
  # must forward navigation intents itself (see
  # PhoenixExRatatui.LiveComponent's moduledoc) — Theatre never emits any
  # today, but this keeps the embed correct if it ever does.
  def handle_info({:phoenix_ex_ratatui, :intent, intent}, socket) do
    {:noreply, PhoenixExRatatui.LiveView.dispatch_intent(socket, intent)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
