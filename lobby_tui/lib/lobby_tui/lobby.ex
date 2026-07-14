defmodule LobbyTui.Lobby do
  @moduledoc """
  The Ash domain for the room. All writes go through the code interfaces below; the Theatre TUI and the web layer never build changesets by hand.
  """

  use Ash.Domain, otp_app: :lobby_tui

  resources do
    resource LobbyTui.Lobby.Avatar do
      define :seed_avatar, action: :seed
      define :list_avatars, action: :read
    end

    resource LobbyTui.Lobby.Attendee do
      define :join, action: :join, args: [:nickname, :avatar_id]
      define :get_attendee, action: :read, get_by: :id
      define :leave, action: :leave, default_options: [return_destroyed?: true]
    end
  end
end
