defmodule LobbyTui.Lobby.Seat do
  @moduledoc """
  One of the 80 theatre seats, seeded at boot from `LobbyTui.World.seats/0`. The layout fields never change; `occupant_id` is the only mutable field, and every write to it is guarded: `:claim` filters on `occupant_id == nil` (or the actor's own, for an idempotent re-sit) and `:stand` filters on `occupant_id == actor`. The ETS data layer has no transactions, so those filters are the guard rather than a lock. There is deliberately no unconditional release action — freeing a seat always states whose seat it is, including when the occupant is leaving the room for good.
  """

  use Ash.Resource,
    otp_app: :lobby_tui,
    domain: LobbyTui.Lobby,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub]

  actions do
    defaults [:read]

    create :seed do
      accept [:row, :col, :x, :y]
      upsert? true
      upsert_identity :unique_position
    end

    read :by_occupant do
      argument :attendee_id, :uuid, allow_nil?: false
      get? true
      filter expr(occupant_id == ^arg(:attendee_id))
    end

    update :claim do
      accept []
      require_atomic? false
      change LobbyTui.Lobby.Seat.Changes.ClaimIfFree
    end

    update :stand do
      accept []
      require_atomic? false
      change LobbyTui.Lobby.Seat.Changes.ReleaseIfOwn
    end
  end

  pub_sub do
    module LobbyTuiWeb.Endpoint
    prefix "lobby"

    publish :claim, "seats"
    publish :stand, "seats"
  end

  attributes do
    uuid_primary_key :id

    attribute :row, :integer do
      allow_nil? false
    end

    attribute :col, :integer do
      allow_nil? false
    end

    attribute :x, :integer do
      allow_nil? false
    end

    attribute :y, :integer do
      allow_nil? false
    end

    attribute :occupant_id, :uuid
  end

  identities do
    identity :unique_position, [:row, :col], pre_check_with: LobbyTui.Lobby
  end
end
