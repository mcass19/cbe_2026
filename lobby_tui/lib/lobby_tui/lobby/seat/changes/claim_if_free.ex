defmodule LobbyTui.Lobby.Seat.Changes.ClaimIfFree do
  @moduledoc """
  The conditional seat claim: filters the update on `occupant_id == nil or occupant_id == actor` so a taken seat matches nothing (the claim errors instead of overwriting) while re-claiming one's own seat is an idempotent no-op — refresh/reconnect calls this the same way as a fresh sit. Then sets the occupant to the actor. An after-action stands the actor up from any other seat they held, so moving seats is a single claim.

  The ETS data layer checks that filter and writes the row as two separate,
  unlocked ETS operations, so two concurrent claimants can both pass the
  check before either writes. To close that window, the data-layer execution
  is wrapped in `Ash.Changeset.around_action/2` and funneled through
  `LobbyTui.Keeper`, a single process that serializes claim execution so
  the check-plus-write is effectively atomic. The changeset filter remains
  the actual correctness condition; the serialization only removes the
  interleaving that let it race.
  """

  use Ash.Resource.Change

  require Ash.Query
  import Ash.Expr

  @impl true
  def change(changeset, _opts, %{actor: %{id: attendee_id} = actor}) do
    changeset
    |> Ash.Changeset.filter(expr(is_nil(occupant_id) or occupant_id == ^attendee_id))
    |> Ash.Changeset.force_change_attribute(:occupant_id, attendee_id)
    |> Ash.Changeset.after_action(fn _changeset, seat ->
      release_other_seats(seat, actor)
      {:ok, seat}
    end)
    |> Ash.Changeset.around_action(fn changeset, callback ->
      LobbyTui.Keeper.serialize(fn -> callback.(changeset) end)
    end)
  end

  def change(changeset, _opts, _no_actor) do
    Ash.Changeset.add_error(changeset, field: :occupant_id, message: "requires an actor")
  end

  defp release_other_seats(%{id: kept_id}, %{id: attendee_id} = actor) do
    LobbyTui.Lobby.Seat
    |> Ash.Query.filter(occupant_id == ^attendee_id and id != ^kept_id)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&LobbyTui.Lobby.stand!(&1, actor: actor))
  end
end
