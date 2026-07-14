defmodule LobbyTui.Lobby.Attendee.Changes.FreeHeldSeat do
  @moduledoc """
  On leave, releases whatever seat the departing attendee held. Runs after the destroy so a crash mid-leave never leaves a seat pointing at a live attendee.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, attendee ->
      case LobbyTui.Lobby.seat_of(attendee.id) do
        {:ok, seat} -> LobbyTui.Lobby.release_seat!(seat)
        {:error, _not_seated} -> :ok
      end

      {:ok, attendee}
    end)
  end
end
