defmodule LobbyTuiWeb.TheatreComponent do
  @moduledoc """
  The browser transport shim: a `PhoenixExRatatui.LiveComponent` whose `tui_*` callbacks delegate 1:1 to `LobbyTui.Theatre`. Parent input arrives as assigns (`:tui_input` for D-pad directions, `:tui_say` for chat submits) via the `tui_component_update/2` hook and is injected into the running TUI.
  """

  use PhoenixExRatatui.LiveComponent

  alias ExRatatui.Event.Key

  def tui_mount_opts(socket), do: [attendee: socket.assigns.attendee]

  def tui_mount(opts), do: LobbyTui.Theatre.mount(opts)
  def tui_render(state, frame), do: LobbyTui.Theatre.render(state, frame)
  def tui_handle_event(event, state), do: LobbyTui.Theatre.handle_event(event, state)
  def tui_handle_info(msg, state), do: LobbyTui.Theatre.handle_info(msg, state)

  def tui_component_update(assigns, socket) do
    tui = socket.assigns[:tui]

    case assigns do
      %{tui_input: dir} when not is_nil(tui) ->
        PhoenixExRatatui.Transport.push_event(tui, %Key{code: dir, kind: "press"})

      %{tui_say: body} when not is_nil(tui) ->
        send(tui.server, {:say, body})

      _plain_assigns ->
        :ok
    end

    {:ok, Phoenix.Component.assign(socket, Map.drop(assigns, [:tui_input, :tui_say]))}
  end
end
