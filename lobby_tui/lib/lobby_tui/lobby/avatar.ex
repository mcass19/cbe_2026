defmodule LobbyTui.Lobby.Avatar do
  @moduledoc """
  A pixel-art avatar, seeded at boot by `LobbyTui.SpriteLoader` from `priv/sprites_src/*.png` and never mutated by attendees. `sprite_cells` holds the half-block cell rows; `dominant_color` is the most frequent opaque pixel, used to color the attendee's single-cell marker in the world grid.
  """

  use Ash.Resource,
    otp_app: :lobby_tui,
    domain: LobbyTui.Lobby,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :seed do
      accept [:name, :sprite_cells, :dominant_color, :license, :attribution]
      upsert? true
      upsert_identity :unique_name
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :sprite_cells, :term, allow_nil?: false
    attribute :dominant_color, :term, allow_nil?: false
    attribute :license, :string
    attribute :attribution, :string
  end

  identities do
    identity :unique_name, [:name], pre_check_with: LobbyTui.Lobby
  end
end
