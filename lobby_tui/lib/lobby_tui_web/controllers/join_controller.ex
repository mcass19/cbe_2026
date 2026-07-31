defmodule LobbyTuiWeb.JoinController do
  use LobbyTuiWeb, :controller

  def new(conn, _params) do
    render(conn, :new, avatars: LobbyTui.Lobby.selectable_avatars!(), error: nil)
  end

  def create(conn, %{"nickname" => nickname, "avatar_id" => avatar_id}) do
    case LobbyTui.Lobby.join(nickname, avatar_id) do
      {:ok, attendee} ->
        conn
        |> put_session(:attendee_id, attendee.id)
        |> redirect(to: ~p"/lobby")

      {:error, error} ->
        render(conn, :new,
          avatars: LobbyTui.Lobby.selectable_avatars!(),
          error: join_error_message(error)
        )
    end
  end

  def create(conn, _missing_params) do
    render(conn, :new,
      avatars: LobbyTui.Lobby.selectable_avatars!(),
      error: "pick a nickname and an avatar"
    )
  end

  @doc """
  Drops the current identity and returns to the join screen.

  Destroying the attendee frees any held seat through
  `LobbyTui.Lobby.Attendee.Changes.FreeHeldSeat`, so no separate stand-up
  step is needed. Clearing the session is why this is a controller action
  and not a LiveView event: `push_navigate/2` cannot drop `:attendee_id`,
  only a real HTTP response can.

  Every step tolerates a stale session. A reaped or already-destroyed
  attendee still lands back on the join screen with the session cleared,
  which also makes the Reaper's pending timer a harmless no-op — it only
  calls `leave` when `get_attendee` still resolves.
  """
  def leave(conn, _params) do
    with attendee_id when is_binary(attendee_id) <- get_session(conn, :attendee_id),
         {:ok, attendee} <- LobbyTui.Lobby.get_attendee(attendee_id) do
      LobbyTui.Lobby.leave(attendee)
    end

    conn
    |> clear_session()
    |> redirect(to: ~p"/")
  end

  defp join_error_message(%Ash.Error.Invalid{errors: errors}) do
    if Enum.any?(errors, &match?(%Ash.Error.Changes.InvalidChanges{}, &1)) or
         Enum.any?(errors, fn e -> :nickname in List.wrap(Map.get(e, :field)) end) do
      "that nickname is taken or invalid — try another (2–16 chars)"
    else
      "could not join — check the nickname and avatar"
    end
  end

  defp join_error_message(_other), do: "could not join — try again"
end
