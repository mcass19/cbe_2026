defmodule SlidesTui.SlideTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias SlidesTui.Test.{FullSlide, MinimalSlide}

  describe "behaviour declaration" do
    test "use SlidesTui.Slide registers the behaviour" do
      behaviours =
        MinimalSlide.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert SlidesTui.Slide in behaviours
    end

    test "render/2 is the only required callback" do
      assert SlidesTui.Slide.behaviour_info(:optional_callbacks) |> Enum.sort() ==
               [handle_event: 2, handle_info: 2, mount: 1, notes: 0, subscriptions: 1, title: 0]
               |> Enum.sort()
    end
  end

  describe "__using__/1" do
    # Fixture modules compile before coverage starts, so expanding the
    # macro during the run is what actually exercises SlidesTui.Slide's
    # own lines — and proves the injected defaults work on a module
    # compiled from scratch.
    test "injects working defaults into a freshly compiled module" do
      code = """
      defmodule SlidesTui.Test.RuntimeCompiledSlide do
        use SlidesTui.Slide

        def render(_state, _area), do: []
      end
      """

      assert [{mod, _binary}] = Code.compile_string(code)

      on_exit(fn ->
        :code.purge(mod)
        :code.delete(mod)
      end)

      assert mod.mount([]) == {:ok, nil}
      assert mod.handle_event(:event, :state) == {:noreply, :state}
      assert mod.handle_info(:msg, :state) == {:noreply, :state}
      assert mod.subscriptions(:state) == []
      assert mod.title() == nil
      assert mod.notes() == nil
    end
  end

  describe "defaults injected by use SlidesTui.Slide" do
    test "mount/1 returns {:ok, nil} regardless of opts" do
      assert MinimalSlide.mount([]) == {:ok, nil}
      assert MinimalSlide.mount(start: 99) == {:ok, nil}
    end

    test "handle_event/2 returns state unchanged" do
      assert MinimalSlide.handle_event(:any_event, :my_state) == {:noreply, :my_state}
    end

    test "handle_info/2 returns state unchanged" do
      assert MinimalSlide.handle_info(:any_msg, :my_state) == {:noreply, :my_state}
    end

    test "subscriptions/1 returns an empty list" do
      assert MinimalSlide.subscriptions(:any_state) == []
    end

    test "title/0 returns nil" do
      assert MinimalSlide.title() == nil
    end

    test "notes/0 returns nil" do
      assert MinimalSlide.notes() == nil
    end
  end

  describe "overrides win over defaults" do
    test "mount/1 reads opts and returns custom state" do
      assert FullSlide.mount([]) == {:ok, %{count: 0}}
      assert FullSlide.mount(start: 3) == {:ok, %{count: 3}}
    end

    test "handle_event/2 transforms the state" do
      assert FullSlide.handle_event(:tick, %{count: 5}) == {:noreply, %{count: 6}}
    end

    test "subscriptions/1 returns the declared list" do
      assert FullSlide.subscriptions(%{count: 0}) == [:tick]
    end

    test "title/0 returns the override string" do
      assert FullSlide.title() == "Full"
    end

    test "notes/0 returns the override markdown" do
      assert FullSlide.notes() == "# Full\n\nsome notes"
    end
  end

  describe "render/2" do
    test "minimal slide returns a single widget covering the area" do
      area = %Rect{x: 0, y: 0, width: 80, height: 24}

      assert [{%ExRatatui.Widgets.Paragraph{text: "minimal"}, ^area}] =
               MinimalSlide.render(nil, area)
    end

    test "full slide renders the count from state" do
      area = %Rect{x: 0, y: 0, width: 80, height: 24}

      assert [{%ExRatatui.Widgets.Paragraph{text: "count: 7"}, ^area}] =
               FullSlide.render(%{count: 7}, area)
    end
  end
end
