defmodule LobbyTui.Lobby do
  @moduledoc """
  The Ash domain for the room. All writes go through the code interfaces below; the Theatre TUI and the web layer never build changesets by hand.
  """

  use Ash.Domain, otp_app: :lobby_tui

  resources do
    resource LobbyTui.Lobby.Avatar do
      define :seed_avatar, action: :seed
      define :list_avatars, action: :read
      define :selectable_avatars, action: :selectable
    end

    resource LobbyTui.Lobby.Attendee do
      define :join, action: :join, args: [:nickname, :avatar_id]
      define :get_attendee, action: :read, get_by: :id
      define :leave, action: :leave, default_options: [return_destroyed?: true]
    end

    resource LobbyTui.Lobby.Seat do
      define :seed_seat, action: :seed
      define :list_seats, action: :read
      define :claim_seat, action: :claim
      define :stand, action: :stand
      define :seat_of, action: :by_occupant, args: [:attendee_id]
    end

    resource LobbyTui.Lobby.Message do
      define :post_message, action: :post, args: [:body]
      define :stage_feed, action: :stage_feed
      define :delete_own_message, action: :delete_own, default_options: [return_destroyed?: true]
      define :moderate_delete, action: :moderate, default_options: [return_destroyed?: true]
    end
  end
end
