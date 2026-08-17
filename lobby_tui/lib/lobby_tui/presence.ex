defmodule LobbyTui.Presence do
  @moduledoc """
  Presence over `LobbyTui.PubSub`: one entry per attendee on `"lobby:presence"`, meta `%{nickname, color, avatar_id, x, y}`. This is the fast lane — positions update here on every step and never touch Ash.
  """

  use Phoenix.Presence, otp_app: :lobby_tui, pubsub_server: LobbyTui.PubSub

  @topic "lobby:presence"

  def topic, do: @topic

  def track_attendee(state), do: track(self(), @topic, state.attendee.id, meta(state))

  def move(state), do: update(self(), @topic, state.attendee.id, meta(state))

  defp meta(state) do
    {x, y} = state.pos

    %{
      nickname: state.attendee.nickname,
      color: state.color,
      avatar_id: state.attendee.avatar_id,
      x: x,
      y: y
    }
  end

  def others(attendee_id) do
    @topic
    |> list()
    |> Map.delete(attendee_id)
    |> Map.new(fn {id, %{metas: [meta | _]}} ->
      {id, Map.take(meta, [:nickname, :color, :avatar_id, :x, :y])}
    end)
  end
end
