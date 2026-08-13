defmodule LobbyTui.Lobby.Join do
  @moduledoc """
  Shared join mechanics for the transports that turn a free-form name into an attendee (`LobbyTui.Ssh`, `LobbyTui.Notebook`): nickname sanitizing, avatar picking, and the join-with-suffix retry loop. Keeping the rules here keeps every transport's idea of a valid nickname identical — an SSH username and a notebook mount option go through exactly the same funnel.
  """

  alias LobbyTui.Lobby

  # Mirrors the `max_length: 16` constraint on `Attendee.nickname`.
  @max_nickname 16

  # A room with more than this many same-named attendees is someone
  # hammering the endpoint, not a coincidence worth accommodating.
  @suffix_attempts 50

  @doc """
  Reduces a free-form name to something the `Attendee` resource will accept: printable characters only, trimmed, at most #{@max_nickname} characters, and `"guest"` when what remains is shorter than the two-character minimum.
  """
  def sanitize_nickname(name) do
    trimmed =
      (name || "")
      |> String.replace(~r/[^[:print:]]/u, "")
      |> String.trim()
      |> String.slice(0, @max_nickname)

    if String.length(trimmed) < 2, do: "guest", else: trimmed
  end

  @doc """
  Picks a seeded avatar by name (the PNG filename minus the extension, e.g. `"monk"`); a `nil` or unknown name falls back to a random one.
  """
  def pick_avatar(nil), do: Enum.random(Lobby.list_avatars!())

  def pick_avatar(name) do
    Enum.find(Lobby.list_avatars!(), &(&1.name == name)) || pick_avatar(nil)
  end

  @doc """
  Joins the room as `base`, suffixing until the nickname is free: "alice", "alice-2", "alice-3" — the suffix eating into the #{@max_nickname}-character budget so the result always fits. Raises any join error that is not a nickname collision.
  """
  def join_with_suffix(base, avatar_id, attempt \\ 1)

  def join_with_suffix(base, avatar_id, attempt) when attempt <= @suffix_attempts do
    case Lobby.join(candidate(base, attempt), avatar_id) do
      {:ok, attendee} ->
        attendee

      {:error, error} ->
        if nickname_taken?(error) do
          join_with_suffix(base, avatar_id, attempt + 1)
        else
          raise error
        end
    end
  end

  defp candidate(base, 1), do: base

  defp candidate(base, attempt) do
    suffix = "-#{attempt}"
    String.slice(base, 0, @max_nickname - String.length(suffix)) <> suffix
  end

  # The identity's uniqueness failure arrives as an
  # `Ash.Error.Changes.InvalidChanges` carrying `fields: [:nickname]`;
  # single-attribute validations use `field:` instead, so both shapes
  # count.
  defp nickname_taken?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn error ->
      Map.get(error, :field) == :nickname or :nickname in List.wrap(Map.get(error, :fields))
    end)
  end

  defp nickname_taken?(_error), do: false
end
