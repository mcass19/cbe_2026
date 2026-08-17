defmodule LobbyTui.Lobby.Attendee.Changes.FreeHeldSeat do
  @moduledoc """
  On leave, stands the departing attendee up from whatever seat they held. Runs after the destroy so a crash mid-leave never leaves a seat pointing at a live attendee. The departing attendee is passed as the actor, so this goes through the same ownership-filtered `:stand` as a deliberate stand — there is no unconditional release to reach for. A failure is swallowed here: the attendee is already gone, and raising would crash the leave itself.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, attendee ->
      case LobbyTui.Lobby.seat_of(attendee.id) do
        {:ok, seat} -> LobbyTui.Lobby.stand(seat, actor: attendee)
        {:error, _not_seated} -> :ok
      end

      {:ok, attendee}
    end)
  end
end
