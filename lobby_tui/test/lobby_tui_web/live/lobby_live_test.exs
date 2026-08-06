defmodule LobbyTuiWeb.LobbyLiveTest do
  use LobbyTuiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    LobbyTui.SpriteLoader.load_all!()
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  defp join_conn(conn) do
    avatar = hd(LobbyTui.Lobby.list_avatars!())
    attendee = LobbyTui.Lobby.join!("lv_#{System.unique_integer([:positive])}", avatar.id)
    {Plug.Test.init_test_session(conn, %{attendee_id: attendee.id}), attendee}
  end

  # The embedded TheatreComponent only boots the real TUI transport (and
  # populates `socket.assigns.tui`) once it receives a
  # "phx_ex_ratatui:resize" hook event — normally fired by the JS hook's
  # ResizeObserver. Phoenix.LiveViewTest never runs JS, so tests that need
  # the transport up (to relay chat input into the TUI, for example) fire
  # it by hand, exactly like phoenix_ex_ratatui's own LiveComponent tests do.
  defp boot_transport(view) do
    view
    |> element("#theatre")
    |> render_hook("phx_ex_ratatui:resize", %{"cols" => 40, "rows" => 20})

    assert_push_event(view, "phx_ex_ratatui:render", _payload, 1000)
    theatre_tui(view)
  end

  # Clicks a #d-pad button and settles both the parent LV process (which
  # runs send_update -> tui_component_update) and the TUI's own GenServer
  # process (which then applies the movement/sit and may broadcast) before
  # returning, so the next click observes an up-to-date position/seat state.
  defp dpad_click(view, tui, dir) do
    view |> element("#d-pad button[phx-value-dir=#{dir}]") |> render_click()
    _ = :sys.get_state(view.pid)
    _ = :sys.get_state(tui.server)
    :ok
  end

  # `#sit-button`'s `phx-value-dir` toggles between "s" and a literal space
  # once seated — a space is not a valid unquoted CSS attribute value, so
  # this clicks it by id rather than by `dpad_click`'s attribute selector.
  defp sit_button_click(view, tui) do
    view |> element("#sit-button") |> render_click()
    _ = :sys.get_state(view.pid)
    _ = :sys.get_state(tui.server)
    :ok
  end

  # `LobbyTui.Lobby` runs on the ETS data layer with no per-test sandbox, so
  # seats claimed by other test files in the same suite run stay claimed for
  # the rest of the run. Pick whichever seat is free *right now* and walk
  # there via BFS over `World.walkable?/1`, rather than assuming any fixed
  # seat/path is free.
  defp free_seat! do
    LobbyTui.Lobby.list_seats!()
    |> Enum.find(&is_nil(&1.occupant_id))
    |> case do
      nil -> flunk("no free seat")
      seat -> {seat.x, seat.y}
    end
  end

  @directions [up: {0, -1}, down: {0, 1}, left: {-1, 0}, right: {1, 0}]

  defp path_to(target) do
    bfs(:queue.from_list([{LobbyTui.World.spawn_point(), []}]), MapSet.new(), target)
  end

  defp bfs(queue, visited, target) do
    case :queue.out(queue) do
      {{:value, {pos, path}}, _rest} when pos == target ->
        Enum.reverse(path)

      {{:value, {pos, path}}, rest} ->
        {x, y} = pos

        {next_queue, next_visited} =
          Enum.reduce(@directions, {rest, visited}, fn {dir, {dx, dy}}, {q, seen} ->
            next = {x + dx, y + dy}

            if LobbyTui.World.walkable?(next) and not MapSet.member?(seen, next) do
              {:queue.in({next, [Atom.to_string(dir) | path]}, q), MapSet.put(seen, next)}
            else
              {q, seen}
            end
          end)

        bfs(next_queue, next_visited, target)

      {:empty, _} ->
        flunk("no path to #{inspect(target)}")
    end
  end

  # No public API to read a LiveComponent's assigns at runtime; peek at the
  # LV's component registry via :sys.get_state, same trick
  # phoenix_ex_ratatui's own LiveComponent tests use.
  defp theatre_tui(view) do
    state = :sys.get_state(view.pid)

    state.components
    |> elem(0)
    |> Enum.find_value(fn
      {_cid, {_module, "theatre", assigns, _, _}} -> assigns.tui
      _ -> nil
    end)
  end

  test "without a session, /lobby redirects to the join form", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/lobby")
  end

  test "renders chrome: header, TUI component, d-pad, data notice; chat hidden unseated", %{
    conn: conn
  } do
    {conn, _attendee} = join_conn(conn)
    {:ok, view, _html} = live(conn, ~p"/lobby")

    assert has_element?(view, "#page-header")
    assert has_element?(view, "#theatre-wrap")
    assert has_element?(view, "#theatre")
    assert has_element?(view, "#reconnect-banner")
    assert has_element?(view, "#d-pad")
    assert has_element?(view, "#sit-button")
    assert has_element?(view, "#data-notice")
    refute has_element?(view, "#chat-form")
  end

  test "wears the same chrome as the join screen, plus a leave link", %{conn: conn} do
    {conn, _attendee} = join_conn(conn)
    {:ok, view, html} = live(conn, ~p"/lobby")

    # Same title and same footer copy as the join screen — one terminal
    # window, not two related screens.
    assert html =~ LobbyTuiWeb.Layouts.shared_title()
    assert html =~ "lives in memory"
    assert has_element?(view, "#page-header")
    assert has_element?(view, "#leave-link")
  end

  test "the leave link is a confirmed DELETE, not a plain navigation", %{conn: conn} do
    {conn, _attendee} = join_conn(conn)
    {:ok, _view, html} = live(conn, ~p"/lobby")

    # A stray tap on a phone must not silently destroy the attendee and
    # release the seat, and clearing the session needs a real request.
    assert html =~ ~s(data-method="delete")
    assert html =~ "data-confirm"
  end

  # There is no written key legend any more: the pad's buttons name every
  # action they perform, so a row repeating them was only taking space from
  # the room. What has to keep working is the pad itself swapping.
  test "the pad swaps between the arrows and stand, and back again", %{conn: conn} do
    {conn, _attendee} = join_conn(conn)
    {:ok, view, html} = live(conn, ~p"/lobby")
    tui = boot_transport(view)

    refute html =~ "key-bar"
    refute html =~ "[↑↓←→]"

    assert has_element?(view, "#d-pad [phx-value-dir='up']")
    assert has_element?(view, "#sit-button", "sit")

    for dir <- path_to(free_seat!()), do: dpad_click(view, tui, dir)
    sit_button_click(view, tui)

    # Seated, walking is off the table but ▲▼ leaf the stage feed, so the
    # pad keeps those two and drops the sideways arrows.
    assert has_element?(view, "#d-pad [phx-value-dir='up']")
    assert has_element?(view, "#d-pad [phx-value-dir='down']")
    refute has_element?(view, "#d-pad [phx-value-dir='left']")
    assert has_element?(view, "#sit-button", "stand")

    sit_button_click(view, tui)

    assert has_element?(view, "#d-pad [phx-value-dir='left']")
    assert has_element?(view, "#sit-button", "sit")
  end

  test "d-pad clicks and sitting reveal the chat form; posting shows the message", %{conn: conn} do
    {conn, attendee} = join_conn(conn)
    {:ok, view, _html} = live(conn, ~p"/lobby")
    tui = boot_transport(view)

    # Theatre's own `seated?` only flips through its own `try_sit` (walking
    # onto a seat cell, then pressing "s") — it is not derived from the
    # "lobby:seats" broadcast (that only updates the occupancy map, for
    # rendering others' seats). So exercise the real D-pad path: walk from
    # spawn to a seat that's free right now, then click "sit".
    for dir <- path_to(free_seat!()), do: dpad_click(view, tui, dir)
    dpad_click(view, tui, "s")

    # The LV subscribes to lobby:seats and reveals the chat form on its own
    # claim broadcast, settled by dpad_click's sync.
    assert has_element?(view, "#chat-form")
    assert has_element?(view, "#chat-input-0")

    view
    |> form("#chat-form", %{"body" => "hello from the web"})
    |> render_submit()

    # Settle send_update -> tui_component_update (parent LV process), then the
    # {:say, body} message it fires into the TUI's own GenServer process:
    _ = :sys.get_state(view.pid)
    _ = :sys.get_state(tui.server)

    {:ok, [message | _]} = LobbyTui.Lobby.stage_feed(actor: attendee)
    assert message.body == "hello from the web"

    # LobbyLive bumps :chat_seq on every send, so the chat input's DOM id
    # changes and LiveView mounts a brand-new (empty) input rather than
    # morphing the old one — the field clears without a JS hook.
    refute has_element?(view, "#chat-input-0")
    assert has_element?(view, "#chat-input-1")
    refute view |> element("#chat-input-1") |> render() =~ "hello from the web"
  end

  test "the sit button becomes a stand button once seated, and frees the seat when clicked", %{
    conn: conn
  } do
    {conn, attendee} = join_conn(conn)
    {:ok, view, _html} = live(conn, ~p"/lobby")
    tui = boot_transport(view)

    assert has_element?(view, "#sit-button", "sit")

    for dir <- path_to(free_seat!()), do: dpad_click(view, tui, dir)
    sit_button_click(view, tui)

    assert has_element?(view, "#chat-form")
    assert has_element?(view, "#sit-button", "stand")

    sit_button_click(view, tui)

    refute has_element?(view, "#chat-form")
    assert has_element?(view, "#sit-button", "sit")
    assert {:error, _} = LobbyTui.Lobby.seat_of(attendee.id)
  end

  test "d-pad click does not crash and returns the view", %{conn: conn} do
    {conn, _attendee} = join_conn(conn)
    {:ok, view, _html} = live(conn, ~p"/lobby")
    assert view |> element("#d-pad button[phx-value-dir=up]") |> render_click()
  end
end
