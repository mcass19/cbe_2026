defmodule LobbyTui.ReaperTest do
  use ExUnit.Case, async: false

  alias LobbyTui.Lobby

  defp join! do
    avatar =
      Lobby.seed_avatar!(%{
        name: "r_#{System.unique_integer([:positive])}",
        sprite_cells: [],
        dominant_color: {:rgb, 0, 0, 0},
        license: "CC0",
        attribution: "test"
      })

    Lobby.join!("reap_#{System.unique_integer([:positive])}", avatar.id)
  end

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
