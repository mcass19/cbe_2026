defmodule LobbyTui.Lobby.Seat.Changes.ReleaseIfOwn do
  @moduledoc """
  The conditional stand: filters the update on `occupant_id == actor` so
  standing from a seat someone else holds matches nothing (the stand errors
  instead of stealing it), then clears the occupant.

  Unlike `ClaimIfFree`, this needs no `LobbyTui.Keeper` serialization.
  Two concurrent claimants racing to fill the same nil slot is the only
  interleaving `Keeper` closes; a stand can never race a claim into
  double-occupancy because the two filters are mutually exclusive on the
  same row — a claim's filter requires `occupant_id` to be `nil` (or
  already the actor's own), and a stand's filter requires `occupant_id` to
  equal the actor releasing it. There is no interleaving of a stand and a
  claim by a *different* actor that both pass their filter against the same
  row: whichever runs first either frees the seat (so a subsequent claim by
  someone else sees `nil` and legitimately wins it) or claims it (so a
  subsequent stand by the original occupant sees a foreign `occupant_id`
  and legitimately errors). The unlocked-ETS check-then-write race that
  `ClaimIfFree` guards against is specifically two *claims* both reading
  `nil` before either writes — that scenario has no stand-side equivalent
  because a stand's filter reads the actor's own id, not `nil`.
  """

  use Ash.Resource.Change

  import Ash.Expr

  @impl true
  def change(changeset, _opts, %{actor: %{id: attendee_id}}) do
    changeset
    |> Ash.Changeset.filter(expr(occupant_id == ^attendee_id))
    |> Ash.Changeset.force_change_attribute(:occupant_id, nil)
  end

  def change(changeset, _opts, _no_actor) do
    Ash.Changeset.add_error(changeset, field: :occupant_id, message: "requires an actor")
  end
end
