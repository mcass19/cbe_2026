defmodule LobbyTui.Lobby.SeatTest do
  use ExUnit.Case, async: false

  alias LobbyTui.Lobby

  setup do
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  defp join!(nick_prefix) do
    avatar =
      Lobby.seed_avatar!(%{
        name: "a_#{System.unique_integer([:positive])}",
        sprite_cells: [],
        dominant_color: {:rgb, 0, 0, 0},
        license: "CC0",
        attribution: "test"
      })

    Lobby.join!("#{nick_prefix}_#{System.unique_integer([:positive])}", avatar.id)
  end

  defp free_seat! do
    Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id)) ||
      flunk("no free seat available")
  end

  test "seeding is idempotent and yields 120 seats" do
    LobbyTui.Lobby.Seeder.seed_seats!()
    assert length(Lobby.list_seats!()) == 120
  end

  test "an attendee claims a free seat" do
    attendee = join!("sitter")
    seat = free_seat!()
    assert {:ok, claimed} = Lobby.claim_seat(seat, actor: attendee)
    assert claimed.occupant_id == attendee.id
  end

  test "claiming an occupied seat fails" do
    a = join!("first")
    b = join!("second")
    seat = free_seat!()
    {:ok, _} = Lobby.claim_seat(seat, actor: a)
    assert {:error, _} = Lobby.claim_seat(seat, actor: b)
  end

  test "the critical concurrency race: exactly one of N claimants wins" do
    seat = free_seat!()
    attendees = for _ <- 1..8, do: join!("racer")

    results =
      attendees
      |> Task.async_stream(&Lobby.claim_seat(seat, actor: &1), timeout: :infinity)
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
  end

  test "re-claiming one's own already-held seat succeeds (idempotent re-sit)" do
    attendee = join!("resitter")
    seat = free_seat!()
    {:ok, _} = Lobby.claim_seat(seat, actor: attendee)
    assert {:ok, reclaimed} = Lobby.claim_seat(seat, actor: attendee)
    assert reclaimed.occupant_id == attendee.id
  end

  test "claiming a second seat releases the first (moving seats)" do
    attendee = join!("mover")
    [seat_a, seat_b | _] = Enum.filter(Lobby.list_seats!(), &is_nil(&1.occupant_id))
    {:ok, _} = Lobby.claim_seat(seat_a, actor: attendee)
    {:ok, _} = Lobby.claim_seat(seat_b, actor: attendee)
    {:ok, held} = Lobby.seat_of(attendee.id)
    assert held.id == seat_b.id
  end

  test "seat_of returns error when the attendee stands" do
    attendee = join!("stander")
    assert {:error, _} = Lobby.seat_of(attendee.id)
  end

  test "leave frees the held seat" do
    attendee = join!("leaver")
    seat = free_seat!()
    {:ok, _} = Lobby.claim_seat(seat, actor: attendee)
    {:ok, _} = Lobby.leave(attendee)
    refreshed = Enum.find(Lobby.list_seats!(), &(&1.id == seat.id))
    assert refreshed.occupant_id == nil
  end
end
