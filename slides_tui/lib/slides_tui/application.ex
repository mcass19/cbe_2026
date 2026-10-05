defmodule SlidesTui.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Presenter sessions register here, keyed by the host they follow,
    # so the host can push them every slide change.
    children = [{Registry, keys: :duplicate, name: SlidesTui.Registry}]
    opts = [strategy: :one_for_one, name: SlidesTui.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
