defmodule LobbyTui.ReaperTest do
  use ExUnit.Case, async: false

  import LobbyTui.RoomFixtures

  alias LobbyTui.Lobby

  test "an attendee is removed grace_ms after their presence leaves" do
    attendee = join!()
    reaper = start_supervised!({LobbyTui.Reaper, grace_ms: 10, name: :test_reaper_a})

    send(reaper, %Phoenix.Socket.Broadcast{
      topic: "lobby:presence",
      event: "presence_diff",
      payload: %{joins: %{}, leaves: %{attendee.id => %{metas: []}}}
    })

    :ok = await_gone(attendee.id, 100)
  end

  test "rejoining within the grace period cancels the reap" do
    attendee = join!()
    reaper = start_supervised!({LobbyTui.Reaper, grace_ms: 50, name: :test_reaper_b})

    diff = fn joins, leaves ->
      %Phoenix.Socket.Broadcast{
        topic: "lobby:presence",
        event: "presence_diff",
        payload: %{joins: joins, leaves: leaves}
      }
    end

    send(reaper, diff.(%{}, %{attendee.id => %{metas: []}}))
    send(reaper, diff.(%{attendee.id => %{metas: []}}, %{}))
    _ = :sys.get_state(reaper)

    Process.sleep(80)
    assert {:ok, _still_there} = Lobby.get_attendee(attendee.id)
  end

  test "a movement-shaped diff (same id in joins and leaves) schedules no reap" do
    attendee = join!()
    reaper = start_supervised!({LobbyTui.Reaper, grace_ms: 10, name: :test_reaper_c})

    send(reaper, %Phoenix.Socket.Broadcast{
      topic: "lobby:presence",
      event: "presence_diff",
      payload: %{
        joins: %{attendee.id => %{metas: []}},
        leaves: %{attendee.id => %{metas: []}}
      }
    })

    _ = :sys.get_state(reaper)

    Process.sleep(50)

    assert {:ok, _still_there} = Lobby.get_attendee(attendee.id)
    assert %{} = :sys.get_state(reaper)
  end

  test "a partial-leave diff does not reap an attendee still tracked in Presence" do
    attendee = join!()
    reaper = start_supervised!({LobbyTui.Reaper, grace_ms: 10, name: :test_reaper_e})

    # Simulate a second connection for the same attendee id (longpoll→
    # websocket swap, or a second tab): a live Presence entry stays tracked
    # even though this diff reports the id as a leave.
    {:ok, _ref} = LobbyTui.Presence.track(self(), LobbyTui.Presence.topic(), attendee.id, %{})

    send(reaper, %Phoenix.Socket.Broadcast{
      topic: "lobby:presence",
      event: "presence_diff",
      payload: %{joins: %{}, leaves: %{attendee.id => %{metas: []}}}
    })

    _ = :sys.get_state(reaper)
    Process.sleep(50)

    assert {:ok, _still_there} = Lobby.get_attendee(attendee.id)

    LobbyTui.Presence.untrack(self(), LobbyTui.Presence.topic(), attendee.id)
  end

  test "a second leave with no join between re-arms the grace period from the later one" do
    attendee = join!()
    reaper = start_supervised!({LobbyTui.Reaper, grace_ms: 300, name: :test_reaper_e})

    leave = %Phoenix.Socket.Broadcast{
      topic: "lobby:presence",
      event: "presence_diff",
      payload: %{joins: %{}, leaves: %{attendee.id => %{metas: []}}}
    }

    # One attendee, two tabs, closed a while apart. Scheduling over the top
    # of the first timer without cancelling it left that timer armed: it
    # fired at the first leave's deadline and reaped 200 ms early.
    send(reaper, leave)
    Process.sleep(200)
    send(reaper, leave)
    _ = :sys.get_state(reaper)

    Process.sleep(150)
    assert {:ok, _still_here} = Lobby.get_attendee(attendee.id)

    :ok = await_gone(attendee.id, 400)
  end

  test "a stale reap message for an untracked id is ignored" do
    attendee = join!()
    reaper = start_supervised!({LobbyTui.Reaper, grace_ms: 10, name: :test_reaper_d})

    send(reaper, {:reap, attendee.id})
    _ = :sys.get_state(reaper)

    assert {:ok, _still_there} = Lobby.get_attendee(attendee.id)
  end

  defp await_gone(_id, 0), do: flunk("attendee was not reaped")

  defp await_gone(id, tries) do
    case Lobby.get_attendee(id) do
      {:error, _} ->
        :ok

      {:ok, _} ->
        Process.sleep(5)
        await_gone(id, tries - 1)
    end
  end
end
