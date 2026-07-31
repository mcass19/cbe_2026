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

  test "GET / wears the shared chrome and offers no leave link", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~s(id="page-header")
    assert html =~ LobbyTuiWeb.Layouts.shared_title()
    assert html =~ "[source]"
    # Nothing to leave yet — the link belongs to the room only.
    refute html =~ ~s(id="leave-link")
  end

  describe "DELETE /leave" do
    test "destroys the attendee, clears the session, and returns to the join screen", %{
      conn: conn
    } do
      {:ok, attendee} = LobbyTui.Lobby.join("leaver", an_avatar_id())

      conn =
        conn |> Plug.Test.init_test_session(%{attendee_id: attendee.id}) |> delete(~p"/leave")

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :attendee_id) == nil
      assert {:error, _} = LobbyTui.Lobby.get_attendee(attendee.id)
    end

    test "frees the nickname so the same one can be taken again", %{conn: conn} do
      {:ok, attendee} = LobbyTui.Lobby.join("recycled", an_avatar_id())

      conn |> Plug.Test.init_test_session(%{attendee_id: attendee.id}) |> delete(~p"/leave")

      assert {:ok, _} = LobbyTui.Lobby.join("recycled", an_avatar_id())
    end

    test "tolerates a stale attendee_id", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{attendee_id: Ash.UUID.generate()})
        |> delete(~p"/leave")

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :attendee_id) == nil
    end

    test "tolerates no session at all", %{conn: conn} do
      conn = conn |> Plug.Test.init_test_session(%{}) |> delete(~p"/leave")

      assert redirected_to(conn) == ~p"/"
    end
  end

  test "GET / does not offer the built-in unknown fallback avatar", %{conn: conn} do
    unknown = Enum.find(LobbyTui.Lobby.list_avatars!(), &(&1.name == "unknown"))
    html = conn |> get(~p"/") |> html_response(200)

    refute html =~ unknown.id
    refute "unknown" in Enum.map(LobbyTui.Lobby.selectable_avatars!(), & &1.name)
  end

  # Regression for the sprite double-width/vanishing-cell bug: a newline
  # (or any whitespace) between two cell `<span>`s collapses to a visible
  # extra space under the browser's default `white-space: normal`, so the
  # `span.sprite` subtree's serialized markup must contain no whitespace
  # between one span's `</span>` and the next. Scoped to `span.sprite` (via
  # LazyHTML) rather than the whole page, since whitespace between a
  # sprite and its unrelated page siblings is expected and harmless.
  test "GET / renders sprites with no whitespace between cell spans", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    sprites_html =
      html
      |> LazyHTML.from_document()
      |> LazyHTML.query("span.sprite")
      |> LazyHTML.to_html()

    assert sprites_html =~ ~s(class="sprite")

    refute sprites_html =~ ~r/<\/span>\s+<span/,
           "expected no whitespace between adjacent sprite spans, got: #{sprites_html}"
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
