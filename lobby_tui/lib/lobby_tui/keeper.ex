defmodule LobbyTui.Keeper do
  @moduledoc """
  Serializes every check-then-write in the domain.

  The ETS data layer has no transactions: it evaluates a changeset filter (or
  an identity's `pre_check_with` query) and writes the row as two separate,
  unlocked operations, so two concurrent writers can both pass the check
  before either writes. Funneling those actions through this single process
  makes check-plus-write effectively atomic.

  Two actions need it, for the same reason:

    * `LobbyTui.Lobby.Seat.Changes.ClaimIfFree` — the `is_nil(occupant_id)`
      claim filter, or two people land on one seat.
    * `LobbyTui.Lobby.Attendee.Changes.SerializeJoin` — the `unique_nickname`
      identity, or a room of attendees who all typed the same name at once
      each pass the collision check and join un-suffixed.

  The check itself remains the correctness condition in both cases; this
  process only removes the interleaving that let it race. Actions serialized
  here must never call back into another serialized action — the nested
  `GenServer.call/3` would deadlock against this process.
  """

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts), do: {:ok, nil}

  def serialize(fun) when is_function(fun, 0), do: GenServer.call(__MODULE__, {:run, fun})

  @impl true
  def handle_call({:run, fun}, _from, state) do
    # A raise inside a serialized action must not kill this singleton — every
    # other in-flight and future write funnels through it. Callers already
    # handle `{:error, _}`, so a rescued exception degrades to an ordinary
    # error reply instead of taking the process (and the whole serialization
    # point) down.
    result =
      try do
        fun.()
      rescue
        exception -> {:error, exception}
      end

    {:reply, result, state}
  end
end
