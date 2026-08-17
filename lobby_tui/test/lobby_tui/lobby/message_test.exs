defmodule LobbyTui.Lobby.MessageTest do
  use ExUnit.Case, async: false

  import LobbyTui.RoomFixtures

  alias LobbyTui.Lobby

  setup do
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  test "a seated attendee posts; the message captures author fields" do
    attendee = seat!(join!())
    assert {:ok, msg} = Lobby.post_message("hello room", actor: attendee)
    assert msg.body == "hello room"
    assert msg.author_attendee_id == attendee.id
    assert msg.author_nickname == attendee.nickname
    assert msg.author_avatar_id == attendee.avatar_id
  end

  test "posting without a seat is forbidden" do
    attendee = join!()
    assert {:error, %Ash.Error.Forbidden{}} = Lobby.post_message("nope", actor: attendee)
  end

  test "Ash.can? mirrors the seat gate" do
    unseated = join!()
    seated = seat!(join!())
    refute Ash.can?({LobbyTui.Lobby.Message, :post, %{body: "hi"}}, unseated)
    assert Ash.can?({LobbyTui.Lobby.Message, :post, %{body: "hi"}}, seated)
  end

  test "reading the feed requires a seat and returns newest first, max 50" do
    unseated = join!()
    seated = seat!(join!())
    {:ok, _} = Lobby.post_message("first", actor: seated)
    {:ok, _} = Lobby.post_message("second", actor: seated)

    assert {:error, %Ash.Error.Forbidden{}} = Lobby.stage_feed(actor: unseated)
    assert {:ok, [%{body: "second"}, %{body: "first"} | _]} = Lobby.stage_feed(actor: seated)
  end

  test "the 7th message inside a minute is refused" do
    attendee = seat!(join!())
    for i <- 1..6, do: {:ok, _} = Lobby.post_message("m#{i}", actor: attendee)
    assert {:error, %Ash.Error.Forbidden{}} = Lobby.post_message("m7", actor: attendee)
  end

  test "authors delete their own messages, not others'" do
    author = seat!(join!())
    other = seat!(join!())
    {:ok, msg} = Lobby.post_message("mine", actor: author)
    assert {:error, %Ash.Error.Forbidden{}} = Lobby.delete_own_message(msg, actor: other)
    assert {:ok, _} = Lobby.delete_own_message(msg, actor: author)
  end

  test "the admin actor bypasses policies for moderation" do
    author = seat!(join!())
    {:ok, msg} = Lobby.post_message("moderate me", actor: author)
    assert {:ok, _} = Lobby.moderate_delete(msg, actor: %LobbyTui.Admin{})
  end

  test "body length is constrained to 1..200" do
    attendee = seat!(join!())
    assert {:error, %Ash.Error.Invalid{}} = Lobby.post_message("", actor: attendee)

    assert {:error, %Ash.Error.Invalid{}} =
             Lobby.post_message(String.duplicate("a", 201), actor: attendee)
  end

  test "posting with a non-attendee actor is rejected by CaptureAuthor" do
    assert {:error, %Ash.Error.Invalid{}} =
             Lobby.post_message("no author", actor: %LobbyTui.Admin{})
  end

  test "moderation is forbidden to everyone but the admin actor" do
    author = seat!(join!())
    bystander = seat!(join!())
    {:ok, msg} = Lobby.post_message("not yours to moderate", actor: author)

    # The bypass is what grants moderation; without a test on this side, a
    # broken bypass condition would hand every attendee the moderate action.
    assert {:error, %Ash.Error.Forbidden{}} = Lobby.moderate_delete(msg, actor: bystander)
    assert {:error, %Ash.Error.Forbidden{}} = Lobby.moderate_delete(msg, actor: author)
    assert {:error, _} = Lobby.moderate_delete(msg, actor: nil)
  end

  test "an actor-less caller can neither post nor read the feed" do
    seated = seat!(join!())
    {:ok, _} = Lobby.post_message("visible to the seated", actor: seated)

    # The endpoint is unauthenticated, so an actor-less call is the default
    # path for anything reaching the domain without an attendee. Posting is
    # refused by `CaptureAuthor` before the authorizer runs; reading has no
    # such change, so it falls through to `HoldsSeat`'s
    # `match?(_actor, _, _), do: false` clause.
    assert {:error, %Ash.Error.Invalid{}} = Lobby.post_message("anon", actor: nil)
    assert {:error, %Ash.Error.Forbidden{}} = Lobby.stage_feed(actor: nil)
  end
end
