defmodule LobbyTui.Lobby.Message do
  @moduledoc """
  A stage-feed message. Author fields are denormalized copies captured at post time (see `Changes.CaptureAuthor`); the feed renders standalone and is pseudonymized the moment its author leaves. Survives for the server's uptime, wiped on restart.
  """

  use Ash.Resource,
    otp_app: :lobby_tui,
    domain: LobbyTui.Lobby,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  actions do
    create :post do
      accept [:body]
      change LobbyTui.Lobby.Message.Changes.CaptureAuthor
    end

    read :stage_feed do
      primary? true
      prepare build(sort: [inserted_at: :desc], limit: 50)
    end

    destroy :delete_own

    destroy :moderate
  end

  policies do
    bypass actor_attribute_equals(:__struct__, LobbyTui.Admin) do
      authorize_if always()
    end

    policy action(:post) do
      authorize_if LobbyTui.Lobby.Checks.HoldsSeat
    end

    policy action(:post) do
      authorize_if LobbyTui.Lobby.Checks.WithinRateLimit
    end

    policy action(:stage_feed) do
      access_type :strict
      authorize_if LobbyTui.Lobby.Checks.HoldsSeat
    end

    policy action(:delete_own) do
      authorize_if expr(author_attendee_id == ^actor(:id))
    end

    policy action(:moderate) do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 200, trim?: true
    end

    attribute :author_attendee_id, :uuid, allow_nil?: false
    attribute :author_nickname, :string, allow_nil?: false
    attribute :author_avatar_id, :uuid, allow_nil?: false

    create_timestamp :inserted_at
  end
end
