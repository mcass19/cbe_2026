defmodule LobbyTui.Lobby.SeatTest do
  use ExUnit.Case, async: false

  import LobbyTui.RoomFixtures

  alias LobbyTui.Lobby

  setup do
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  test "seeding is idempotent and yields one record per world seat" do
    LobbyTui.Lobby.Seeder.seed_seats!()
    assert length(Lobby.list_seats!()) == length(LobbyTui.World.seats())
  end

  test "an attendee claims a free seat" do
    attendee = join!(prefix: "sitter")
    seat = free_seat!()
    assert {:ok, claimed} = Lobby.claim_seat(seat, actor: attendee)
    assert claimed.occupant_id == attendee.id
  end

  test "claiming an occupied seat fails" do
    a = join!(prefix: "first")
    b = join!(prefix: "second")
    seat = free_seat!()
    {:ok, _} = Lobby.claim_seat(seat, actor: a)
    assert {:error, _} = Lobby.claim_seat(seat, actor: b)
  end

  test "the critical concurrency race: exactly one of N claimants wins" do
    seat = free_seat!()
    attendees = for _ <- 1..8, do: join!(prefix: "racer")

    results =
      attendees
      |> Task.async_stream(&Lobby.claim_seat(seat, actor: &1), timeout: :infinity)
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
  end

  test "re-claiming one's own already-held seat succeeds (idempotent re-sit)" do
    attendee = join!(prefix: "resitter")
    seat = free_seat!()
    {:ok, _} = Lobby.claim_seat(seat, actor: attendee)
    assert {:ok, reclaimed} = Lobby.claim_seat(seat, actor: attendee)
    assert reclaimed.occupant_id == attendee.id
  end

  test "claiming a second seat releases the first (moving seats)" do
    attendee = join!(prefix: "mover")
    [seat_a, seat_b | _] = Enum.filter(Lobby.list_seats!(), &is_nil(&1.occupant_id))
    {:ok, _} = Lobby.claim_seat(seat_a, actor: attendee)
    {:ok, _} = Lobby.claim_seat(seat_b, actor: attendee)
    {:ok, held} = Lobby.seat_of(attendee.id)
    assert held.id == seat_b.id
  end

  test "seat_of returns error when the attendee stands" do
    attendee = join!(prefix: "stander")
    assert {:error, _} = Lobby.seat_of(attendee.id)
  end

  test "leave frees the held seat" do
    attendee = join!(prefix: "leaver")
    seat = free_seat!()
    {:ok, _} = Lobby.claim_seat(seat, actor: attendee)
    {:ok, _} = Lobby.leave(attendee)
    refreshed = Enum.find(Lobby.list_seats!(), &(&1.id == seat.id))
    assert refreshed.occupant_id == nil
  end

  test "stand releases the attendee's own seat" do
    attendee = join!(prefix: "stander")
    seat = free_seat!()
    {:ok, claimed} = Lobby.claim_seat(seat, actor: attendee)
    assert {:ok, stood} = Lobby.stand(claimed, actor: attendee)
    assert stood.occupant_id == nil
    assert {:error, _} = Lobby.seat_of(attendee.id)
  end

  test "stand on someone else's seat errors and leaves it occupied" do
    owner = join!(prefix: "owner")
    other = join!(prefix: "bystander")
    seat = free_seat!()
    {:ok, claimed} = Lobby.claim_seat(seat, actor: owner)

    assert {:error, _} = Lobby.stand(claimed, actor: other)
    refreshed = Enum.find(Lobby.list_seats!(), &(&1.id == claimed.id))
    assert refreshed.occupant_id == owner.id
  end

  test "stand without an actor errors" do
    attendee = join!(prefix: "noactor")
    seat = free_seat!()
    {:ok, claimed} = Lobby.claim_seat(seat, actor: attendee)
    assert {:error, _} = Lobby.stand(claimed)
  end
end
