defmodule LobbyTui.Lobby.Message.Changes.CaptureAuthor do
  @moduledoc """
  Copies the actor's nickname and avatar onto the message. Deliberate denormalization, load-bearing for privacy: when the author's Attendee row is destroyed on disconnect, the message keeps a name and a sprite but points at nothing.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, %{actor: %LobbyTui.Lobby.Attendee{} = actor}) do
    changeset
    |> Ash.Changeset.force_change_attribute(:author_attendee_id, actor.id)
    |> Ash.Changeset.force_change_attribute(:author_nickname, actor.nickname)
    |> Ash.Changeset.force_change_attribute(:author_avatar_id, actor.avatar_id)
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset,
      field: :author_attendee_id,
      message: "requires an attendee actor"
    )
  end
end
