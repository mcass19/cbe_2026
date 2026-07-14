defmodule LobbyTui.Lobby.Attendee do
  @moduledoc """
  A person in the room: nickname plus avatar, nothing else. Ephemeral by design — the row is destroyed when the attendee disconnects (after the grace period), which is what pseudonymizes any messages they posted. Live position never lives here; it flows through `LobbyTui.Presence` only.
  """

  use Ash.Resource,
    otp_app: :lobby_tui,
    domain: LobbyTui.Lobby,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :join do
      accept [:nickname, :avatar_id]
    end

    destroy :leave do
      # Task 4 adds require_atomic? false + the FreeHeldSeat change here.
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :nickname, :string do
      allow_nil? false
      public? true
      constraints min_length: 2, max_length: 16, trim?: true
    end
  end

  relationships do
    belongs_to :avatar, LobbyTui.Lobby.Avatar do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_nickname, [:nickname], pre_check_with: LobbyTui.Lobby
  end
end
