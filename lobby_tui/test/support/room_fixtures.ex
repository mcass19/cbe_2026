defmodule LobbyTui.RoomFixtures do
  @moduledoc """
  Shared fixtures for tests that need a populated room.

  Every fixture here drives a real domain action — `seed_avatar`, `join`, `claim` — rather than inserting records behind the domain's back. The actions are the factory, so a change that breaks joining or sitting breaks the fixtures too, instead of letting the suite keep passing against a shape the app no longer produces.

  Names are globally unique (`System.unique_integer/1`), which is what keeps the `unique_nickname` identity from deadlocking when tests run concurrently.
  """

  alias LobbyTui.Lobby

  @doc """
  Seeds an avatar. `overrides` is merged over the defaults, for the tests that assert on a specific colour or sprite.
  """
  def seed_avatar!(overrides \\ %{}) do
    Lobby.seed_avatar!(
      Map.merge(
        %{
          name: "avatar_#{System.unique_integer([:positive])}",
          sprite_cells: [],
          dominant_color: {:rgb, 0, 0, 0},
          license: "CC0",
          attribution: "test"
        },
        overrides
      )
    )
  end

  @doc """
  A nickname no other test can collide with. `prefix` is kept short — the cap is 16 characters, and tests that watch a "-2" suffix land need the headroom.
  """
  def unique_nickname(prefix \\ "nick"), do: "#{prefix}_#{System.unique_integer([:positive])}"

  @doc """
  Joins the room, seeding an avatar unless one is passed.

  Options: `:avatar` (an existing avatar), `:nickname` (an exact name), `:prefix` (a prefix for a generated name).
  """
  def join!(opts \\ []) do
    avatar = Keyword.get_lazy(opts, :avatar, fn -> seed_avatar!() end)

    nickname =
      Keyword.get_lazy(opts, :nickname, fn ->
        unique_nickname(Keyword.get(opts, :prefix, "nick"))
      end)

    Lobby.join!(nickname, avatar.id)
  end

  @doc """
  Sits `attendee` in the first free seat and returns them, for the tests whose subject is what a seated attendee may do rather than the sitting itself.
  """
  def seat!(attendee) do
    {:ok, _claimed} = Lobby.claim_seat(free_seat!(), actor: attendee)
    attendee
  end

  @doc """
  The first unoccupied seat. Raises rather than returning nil, so a test that has silently filled the house fails where it went wrong.
  """
  def free_seat! do
    Enum.find(Lobby.list_seats!(), &is_nil(&1.occupant_id)) ||
      raise "no free seat available — all #{length(LobbyTui.World.seats())} are taken"
  end
end
