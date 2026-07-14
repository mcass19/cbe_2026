defmodule LobbyTui.Lobby.Checks.WithinRateLimit do
  @moduledoc """
  The 6-messages-per-minute rule as a policy check, backed by `LobbyTui.RateLimiter`. Counts the attempt at check time, so a forbidden post is still a spent attempt — deliberately, to keep hammering unprofitable.
  """

  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is within the message rate limit"

  @impl true
  def match?(%LobbyTui.Lobby.Attendee{id: attendee_id}, _context, _opts) do
    LobbyTui.RateLimiter.within_limit?(attendee_id)
  end

  def match?(_actor, _context, _opts), do: false
end
