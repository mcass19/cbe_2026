defmodule LobbyTuiWeb.LobbyLive do
  @moduledoc """
  The room page: plain HEEx chrome (header, D-pad, chat input, data-transparency footer) around the embedded Theatre TUI. The chrome is deliberately HTML — the frame is a web page, the world inside is a terminal.
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
      class="fixed top-0 inset-x-0 z-50 hidden bg-amber-100 text-amber-900 text-xs text-center py-1"
      phx-disconnected={JS.show(to: "#reconnect-banner")}
      phx-connected={JS.hide(to: "#reconnect-banner")}
    >
      connection lost — reconnecting
    </div>

    <div id="lobby-shell" class="mx-auto max-w-2xl p-2 flex flex-col gap-2">
      <header id="lobby-header" class="flex justify-between text-sm">
        <span>TUIs everywhere — the lobby</span>
        <a href="https://github.com/mcass19/cbe_2026">source</a>
      </header>

      <div id="theatre-wrap" class="h-[70vh] min-h-[24rem]">
        <.live_component module={TheatreComponent} id="theatre" attendee={@attendee} />
      </div>

      <form :if={@seated?} id="chat-form" phx-submit="say" class="flex gap-2">
        <input
          id={"chat-input-#{@chat_seq}"}
          name="body"
          type="text"
          maxlength="200"
          autocomplete="off"
          autofocus
          enterkeyhint="send"
          placeholder="say something to the room"
          class="flex-1"
        />
        <button type="submit">send</button>
      </form>

      <div id="d-pad" class="flex justify-center gap-2 select-none">
        <button
          class="min-w-12 min-h-12 p-2"
          style="touch-action: manipulation;"
          phx-click="dpad"
          phx-value-dir="left"
        >
          ◄
        </button>
        <button
          class="min-w-12 min-h-12 p-2"
          style="touch-action: manipulation;"
          phx-click="dpad"
          phx-value-dir="up"
        >
          ▲
        </button>
        <button
          class="min-w-12 min-h-12 p-2"
          style="touch-action: manipulation;"
          phx-click="dpad"
          phx-value-dir="down"
        >
          ▼
        </button>
        <button
          class="min-w-12 min-h-12 p-2"
          style="touch-action: manipulation;"
          phx-click="dpad"
          phx-value-dir="right"
        >
          ►
        </button>
        <button
          id="sit-button"
          class="min-w-12 min-h-12 p-2"
          style="touch-action: manipulation;"
          phx-click="dpad"
          phx-value-dir={if @seated?, do: " ", else: "s"}
        >
          {if @seated?, do: "stand", else: "sit"}
        </button>
      </div>

      <footer id="data-notice" class="text-xs text-gray-500">
        Everything here lives in memory (ETS via Ash). You disappear when you disconnect.
        Messages are wiped when the server restarts. Please don't post personal information.
        <a href="https://github.com/mcass19/cbe_2026/blob/main/lobby_tui/docs/PRIVACY.md">
          Privacy note
        </a>
      </footer>
    </div>
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
