defmodule LobbyTui.Admin do
  @moduledoc """
  The moderation actor. Constructed only server-side (remote console or a token-checked caller); passing `%LobbyTui.Admin{}` as the actor trips the bypass policy on Message.
  """

  defstruct []
end
