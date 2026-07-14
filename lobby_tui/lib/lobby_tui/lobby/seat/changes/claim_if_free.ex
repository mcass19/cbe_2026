defmodule LobbyTui.Lobby.Seat.Changes.ClaimIfFree do
  @moduledoc """
  The conditional seat claim: filters the update on `occupant_id == nil` so a taken seat matches nothing and the claim errors instead of overwriting, then sets the occupant to the actor. An after-action releases any other seat the actor held, so moving seats is a single claim.

  The ETS data layer checks that filter and writes the row as two separate,
  unlocked ETS operations, so two concurrent claimants can both pass the
  check before either writes. To close that window, the data-layer execution
  is wrapped in `Ash.Changeset.around_action/2` and funneled through
  `LobbyTui.SeatKeeper`, a single process that serializes claim execution so
  the check-plus-write is effectively atomic. The changeset filter remains
  the actual correctness condition; the serialization only removes the
  interleaving that let it race.
  """

  use Ash.Resource.Change

  require Ash.Query
  import Ash.Expr

  @impl true
  def change(changeset, _opts, %{actor: %{id: attendee_id}}) do
    changeset
    |> Ash.Changeset.filter(expr(is_nil(occupant_id)))
    |> Ash.Changeset.force_change_attribute(:occupant_id, attendee_id)
    |> Ash.Changeset.after_action(fn _changeset, seat ->
      release_other_seats(seat, attendee_id)
      {:ok, seat}
    end)
    |> Ash.Changeset.around_action(fn changeset, callback ->
      LobbyTui.SeatKeeper.serialize(fn -> callback.(changeset) end)
    end)
  end

  def change(changeset, _opts, _no_actor) do
    Ash.Changeset.add_error(changeset, field: :occupant_id, message: "requires an actor")
  end

  defp release_other_seats(%{id: kept_id}, attendee_id) do
    LobbyTui.Lobby.Seat
    |> Ash.Query.filter(occupant_id == ^attendee_id and id != ^kept_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&LobbyTui.Lobby.release_seat!/1)
  end
end
