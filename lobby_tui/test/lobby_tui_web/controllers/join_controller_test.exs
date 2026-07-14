defmodule LobbyTuiWeb.JoinControllerTest do
  use LobbyTuiWeb.ConnCase, async: false

  setup do
    LobbyTui.SpriteLoader.load_all!()
    :ok
  end

  defp an_avatar_id do
    hd(LobbyTui.Lobby.list_avatars!()).id
  end

  test "GET / renders the join form with avatar grid and data notice", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)
    assert html =~ ~s(id="join-form")
    assert html =~ ~s(id="avatar-grid")
    assert html =~ ~s(id="data-notice")
    assert html =~ "lives in memory"
  end

  test "POST /join creates the attendee, sets the session, and redirects", %{conn: conn} do
    nick = "web_#{System.unique_integer([:positive])}"
    conn = post(conn, ~p"/join", %{"nickname" => nick, "avatar_id" => an_avatar_id()})
    assert redirected_to(conn) == ~p"/lobby"
    assert get_session(conn, :attendee_id)
  end

  test "POST /join with a taken nickname re-renders with an error", %{conn: conn} do
    nick = "dup_#{System.unique_integer([:positive])}"
    avatar_id = an_avatar_id()
    post(conn, ~p"/join", %{"nickname" => nick, "avatar_id" => avatar_id})

    html =
      conn
      |> post(~p"/join", %{"nickname" => nick, "avatar_id" => avatar_id})
      |> html_response(200)

    assert html =~ ~s(id="join-error")
  end
end
