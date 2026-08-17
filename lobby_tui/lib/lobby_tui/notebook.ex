defmodule LobbyTui.Notebook do
  @moduledoc """
  The Livebook transport: the same `LobbyTui.Theatre` the browser, the local terminal, and SSH run, rendered into a notebook cell by `Kino.ExRatatui`.

  This is the fourth transport shim, symmetric with `LobbyTuiWeb.TheatreComponent` (browser), `LobbyTui.Local` (local terminal), and `LobbyTui.Ssh` (ssh): it turns a cell evaluation into an attendee, then delegates every ExRatatui callback to `Theatre`. It only makes sense from a Livebook whose runtime is *attached to the running node* — the room's state (Ash ETS tables, Presence, PubSub) lives on that node, so the cell has to execute there to be in the same room as everyone else. From an attached notebook:

      Kino.ExRatatui.new(LobbyTui.Notebook, nickname: "speaker", avatar: "monk")

  The nickname goes through the same funnel as an SSH username (`LobbyTui.Lobby.Join`): sanitized, clamped to 16 characters, and suffixed when already taken. `q` is ignored unless `quit?: true` is passed, matching the browser embed — a stray "q" typed at the projector cannot kill the widget mid-talk; re-evaluating the cell (or `quit?: true`) is the way out. Either way the attendee leaves the room the moment the runtime stops, so the seat frees immediately.

  See the "Livebook" section of the README for the full attach runbook (WireGuard, cookie, node name) and `notebooks/lobby.livemd` for the ready-made talk notebook.
  """

  use ExRatatui.App

  alias LobbyTui.{Lobby, Theatre}
  alias LobbyTui.Lobby.Join

  @default_nickname "notebook"

  @impl true
  def mount(opts) do
    avatar = Join.pick_avatar(Keyword.get(opts, :avatar))

    nickname =
      opts
      |> Keyword.get(:nickname, @default_nickname)
      |> Join.sanitize_nickname()

    case Join.join_with_suffix(nickname, avatar.id) do
      {:ok, attendee} ->
        opts
        |> Keyword.take([:connect?, :quit?])
        |> Keyword.merge(attendee: attendee)
        |> Theatre.mount()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def render(state, frame), do: Theatre.render(state, frame)

  @impl true
  def handle_event(event, state), do: Theatre.handle_event(event, state)

  @impl true
  def handle_info(msg, state), do: Theatre.handle_info(msg, state)

  @doc """
  Leaves the room as the runtime stops.

  A stopped widget is unambiguous — the cell was re-evaluated, the runtime disconnected, or the app was stopped — so the attendee and their seat are released immediately instead of waiting out `LobbyTui.Reaper`'s presence grace period.
  """
  @impl true
  def terminate(_reason, %Theatre.State{attendee: attendee}) when not is_nil(attendee) do
    Lobby.leave(attendee)
    :ok
  end

  def terminate(_reason, _state), do: :ok
end
