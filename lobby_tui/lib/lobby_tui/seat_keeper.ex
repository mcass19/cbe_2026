defmodule LobbyTui.SeatKeeper do
  @moduledoc """
  Serializes seat-claim execution. The ETS data layer checks the claim's
  `is_nil(occupant_id)` filter and writes the row as two separate ETS
  operations, so two concurrent claimants can both pass the check; funneling
  every claim through this single process makes check-plus-write atomic.
  The filter on the changeset remains the correctness condition — this
  process only removes the interleaving.
  """

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts), do: {:ok, nil}

  def serialize(fun) when is_function(fun, 0), do: GenServer.call(__MODULE__, {:run, fun})

  @impl true
  def handle_call({:run, fun}, _from, state), do: {:reply, fun.(), state}
end
