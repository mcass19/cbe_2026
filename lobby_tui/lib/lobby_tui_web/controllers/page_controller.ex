defmodule LobbyTuiWeb.PageController do
  use LobbyTuiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
