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
