defmodule LobbyTui.Lobby.Attendee.Changes.SerializeJoin do
  @moduledoc """
  Runs the join through `LobbyTui.Keeper` so the `unique_nickname` identity is enforced under concurrency.

  The identity's `pre_check_with` query and the ETS insert are two separate, unlocked operations. Without serialization every member of a simultaneous burst of "alice" joins runs its pre-check before any of them writes, all of them see a free nickname, and all of them join as "alice" — the suffix loop in `LobbyTui.Lobby.Join` never fires, because no caller is ever told the name was taken. That burst is the ordinary case for the SSH endpoint, where a roomful of people connect at once.

  Same mechanism, same reason, as `LobbyTui.Lobby.Seat.Changes.ClaimIfFree`.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.around_action(changeset, fn changeset, callback ->
      LobbyTui.Keeper.serialize(fn -> callback.(changeset) end)
    end)
  end
end
