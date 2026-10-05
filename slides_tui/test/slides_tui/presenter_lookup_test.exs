defmodule SlidesTui.PresenterLookupTest do
  # Sync: host tests register their test pids as `:host` while they run,
  # and this module needs the registry to itself.
  use ExUnit.Case, async: false

  alias SlidesTui.Presenter

  test "without a registered host the view starts stopped" do
    assert Registry.lookup(SlidesTui.Registry, :host) == []
    assert {:ok, %Presenter{host: nil, view: :stopped}} = Presenter.init([])
  end

  test "defaults to the host registered in SlidesTui.Registry" do
    {:ok, _} = Registry.register(SlidesTui.Registry, :host, nil)

    assert {:ok, %Presenter{host: host}} = Presenter.init([])
    assert host == self()
    assert_receive {:slides_tui, :sync}
  end
end
