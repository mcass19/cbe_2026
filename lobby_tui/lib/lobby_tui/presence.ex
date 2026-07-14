defmodule LobbyTui.Presence do
  @moduledoc """
  Presence over `LobbyTui.PubSub`: one entry per attendee on `"lobby:presence"`, meta `%{nickname, color, x, y}`. This is the fast lane — positions update here on every step and never touch Ash.
  """

  use Phoenix.Presence, otp_app: :lobby_tui, pubsub_server: LobbyTui.PubSub

  @topic "lobby:presence"

  def topic, do: @topic

  def track_attendee(state) do
    {x, y} = state.pos

    track(self(), @topic, state.attendee.id, %{
      nickname: state.attendee.nickname,
      color: state.color,
      x: x,
      y: y
    })
  end

  def move(state) do
    {x, y} = state.pos

    update(self(), @topic, state.attendee.id, %{
      nickname: state.attendee.nickname,
      color: state.color,
      x: x,
      y: y
    })
  end

  def others(attendee_id) do
    @topic
    |> list()
    |> Map.delete(attendee_id)
    |> Map.new(fn {id, %{metas: [meta | _]}} ->
      {id, Map.take(meta, [:nickname, :color, :x, :y])}
    end)
  end
end
