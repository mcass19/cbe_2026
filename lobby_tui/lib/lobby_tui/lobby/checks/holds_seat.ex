defmodule LobbyTui.Lobby.Checks.HoldsSeat do
  @moduledoc """
  The "sit to participate" rule as a policy check: true when any Seat's `occupant_id` is the actor. Gates both posting and reading the stage feed.
  """

  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor holds a seat"

  @impl true
  def match?(%LobbyTui.Lobby.Attendee{id: attendee_id}, _context, _opts) do
    LobbyTui.Lobby.Seat
    |> Ash.Query.filter(occupant_id == ^attendee_id)
    |> Ash.exists?(authorize?: false)
  end

  def match?(_actor, _context, _opts), do: false
end
