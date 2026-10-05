defmodule SlidesTui.HostTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Event.Key
  alias ExRatatui.Frame
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.{Block, Clear, Paragraph}
  alias SlidesTui.{Host, State, Theme}
  alias SlidesTui.Test.Fixtures.DeckBasic

  @basic_pattern "test/support/fixtures/deck_basic/*.ex"
  @interactive_pattern "test/support/fixtures/deck_interactive/*.ex"
  @frame %Frame{width: 80, height: 24}

  defp basic_state(index) do
    %State{slides: [DeckBasic.Intro, DeckBasic.Overview, DeckBasic.Demo], index: index}
  end

  defp interactive_state(opts \\ []) do
    {:ok, state, _runtime_opts} = Host.init([pattern: @interactive_pattern] ++ opts)
    state
  end

  defp key(code, kind \\ "press"), do: %Key{code: code, kind: kind}

  describe "init/1" do
    test "discovers slides from the given pattern" do
      assert {:ok, state, _runtime_opts} = Host.init(pattern: @basic_pattern)
      assert state.slides == [DeckBasic.Intro, DeckBasic.Overview, DeckBasic.Demo]
      assert state.index == 0
    end

    test "default pattern finds the talk deck under lib/slides/" do
      {:ok, state, _runtime_opts} = Host.init([])
      assert TuisEverywhere.Slides.Title in state.slides
      assert length(state.slides) == length(Path.wildcard("lib/slides/[0-9]*.ex"))
    end

    test "asks the runtime to probe for the best image protocol" do
      assert {:ok, _state, runtime_opts} = Host.init(pattern: @basic_pattern)
      assert runtime_opts[:probe_image_protocol] == true
    end
  end

  describe "themes" do
    test "init/1 starts on the default theme with no size guard" do
      {:ok, state, _} = Host.init(pattern: @basic_pattern)
      assert state.theme == Theme.default()
      assert state.min_size == {0, 0}
    end

    test "init/1 takes :theme and :min_size, and rejects unknown themes" do
      {:ok, state, _} = Host.init(pattern: @basic_pattern, theme: :daylight, min_size: {152, 39})
      assert {state.theme, state.min_size} == {:daylight, {152, 39}}

      assert_raise ArgumentError, fn -> Host.init(pattern: @basic_pattern, theme: :neon) end
    end

    test "t cycles the theme and keeps the slide" do
      state = basic_state(1)
      {:noreply, state} = Host.update({:event, key("t")}, state)
      assert {state.theme, state.index} == {:midnight, 1}

      {:noreply, state} = Host.update({:event, key("t")}, state)
      {:noreply, state} = Host.update({:event, key("t")}, state)
      assert state.theme == :dracula
    end

    test "t works on an empty deck too" do
      assert {:noreply, %State{theme: :midnight}} =
               Host.update({:event, key("t")}, %State{slides: []})
    end

    test "every frame is painted in the active theme's ground and text" do
      daylight = Theme.fetch!(:daylight)
      widgets = Host.render(%{basic_state(0) | theme: :daylight}, @frame)

      assert [{%Clear{}, _}, {%Block{borders: [], style: style}, _} | _] = widgets
      assert {style.fg, style.bg} == {daylight.text, daylight.ground}
      # the slide helpers read the same theme back while rendering
      assert Theme.current() == daylight
    end
  end

  describe "size guard" do
    test "a frame below min_size shows both sizes instead of the slide" do
      state = %{basic_state(0) | min_size: {152, 39}}
      widgets = Host.render(state, @frame)

      assert [{%Clear{}, _}, {%Block{borders: []}, _}, {%Paragraph{text: text}, rect}] = widgets
      assert text =~ "terminal is 80×24, the deck needs 152×39"
      # vertically centred in the frame
      assert rect.y > 0 and rect.y + rect.height < @frame.height
    end

    test "too short alone also trips it, and a big enough frame renders the slide" do
      state = %{basic_state(0) | min_size: {80, 30}}
      assert [_, _, {%Paragraph{text: text}, _}] = Host.render(state, @frame)
      assert text =~ "needs 80×30"

      fits = %{basic_state(0) | min_size: {80, 24}}
      assert [_, _, {%Block{border_type: :rounded}, _} | _] = Host.render(fits, @frame)
    end
  end

  describe "update/2 navigation" do
    test "right arrow advances index" do
      assert {:noreply, %State{index: 1}} = Host.update({:event, key("right")}, basic_state(0))
    end

    test "l also advances (vim binding)" do
      assert {:noreply, %State{index: 1}} = Host.update({:event, key("l")}, basic_state(0))
    end

    test "space and page down also advance (presentation clickers)" do
      assert {:noreply, %State{index: 1}} = Host.update({:event, key(" ")}, basic_state(0))

      assert {:noreply, %State{index: 1}} =
               Host.update({:event, key("page_down")}, basic_state(0))
    end

    test "left arrow goes back" do
      assert {:noreply, %State{index: 0}} = Host.update({:event, key("left")}, basic_state(1))
    end

    test "h also goes back (vim binding)" do
      assert {:noreply, %State{index: 0}} = Host.update({:event, key("h")}, basic_state(1))
    end

    test "page up also goes back (presentation clickers)" do
      assert {:noreply, %State{index: 0}} =
               Host.update({:event, key("page_up")}, basic_state(1))
    end

    test "next clamps at the last slide" do
      assert {:noreply, %State{index: 2}} = Host.update({:event, key("right")}, basic_state(2))
    end

    test "prev clamps at index 0" do
      assert {:noreply, %State{index: 0}} = Host.update({:event, key("left")}, basic_state(0))
    end

    test "next is a safe no-op when there are no slides" do
      state = %State{slides: [], index: 0}
      assert {:noreply, %State{index: 0}} = Host.update({:event, key("right")}, state)
    end

    test "q stops the deck" do
      state = basic_state(0)
      assert {:stop, ^state} = Host.update({:event, key("q")}, state)
    end

    test "non-nav keys delegate to the active slide (DeckBasic uses default no-op)" do
      state = basic_state(0)
      assert {:noreply, new_state} = Host.update({:event, key("x")}, state)
      assert new_state.index == 0
    end

    test "release events also delegate (host doesn't pre-filter on kind)" do
      state = basic_state(0)
      assert {:noreply, new_state} = Host.update({:event, key("right", "release")}, state)
      assert new_state.index == 0
    end

    test "info messages delegate to the active slide's handle_info (default no-op)" do
      state = basic_state(0)
      assert {:noreply, new_state} = Host.update({:info, :anything}, state)
      assert new_state.index == 0
    end

    test "ignores envelopes that aren't {:event, _} or {:info, _}" do
      state = basic_state(0)
      assert {:noreply, ^state} = Host.update(:unexpected, state)
    end
  end

  describe "lazy mount" do
    test "init mounts slide 0 only" do
      state = interactive_state()
      assert Map.has_key?(state.slide_states, 0)
      assert map_size(state.slide_states) == 1
    end

    test "init stores opts for later mounts" do
      state = interactive_state(start: 7)
      assert state.opts[:start] == 7
    end

    test "advancing to a new slide mounts it on first visit, using host opts" do
      state = interactive_state(start: 7)
      {:noreply, state} = Host.update({:event, key("right")}, state)

      assert state.index == 1
      assert state.slide_states[1] == %{count: 7}
    end

    test "navigating away and back preserves the slide_state (no re-mount)" do
      state = interactive_state()
      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("x")}, state)
      assert state.slide_states[1] == %{count: 1}

      {:noreply, state} = Host.update({:event, key("left")}, state)
      {:noreply, state} = Host.update({:event, key("right")}, state)
      assert state.slide_states[1] == %{count: 1}
    end
  end

  describe "handle_event routing to the active slide" do
    test "non-nav event reaches the slide's handle_event with its state" do
      state = interactive_state()
      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("x")}, state)
      assert state.slide_states[1].count == 1
    end

    test "slide returning {:stop, _} stops the deck" do
      state = interactive_state()
      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("right")}, state)
      assert state.index == 2

      assert {:stop, _} = Host.update({:event, key("anything")}, state)
    end

    test "events to an empty deck are ignored" do
      state = %State{slides: [], index: 0}
      assert {:noreply, ^state} = Host.update({:event, key("x")}, state)
    end
  end

  describe "presenter protocol" do
    # Host.update/2 runs in the test process here, so the test plays the
    # presenter session following "its" host.
    setup do
      {:ok, _} = Registry.register(SlidesTui.Registry, {:presenter, self()}, nil)
      :ok
    end

    test "init registers the host and takes :talk_minutes" do
      {:ok, state, _} = Host.init(pattern: @basic_pattern, talk_minutes: 40)
      assert state.talk_minutes == 40
      assert {self(), nil} in Registry.lookup(SlidesTui.Registry, :host)
    end

    test "next and prev messages navigate like the keys" do
      assert {:noreply, %State{index: 1}} =
               Host.update({:info, {:slides_tui, :next}}, basic_state(0))

      assert {:noreply, %State{index: 0}} =
               Host.update({:info, {:slides_tui, :prev}}, basic_state(1))
    end

    test "a slide change pushes the new view to presenters" do
      {:noreply, _} = Host.update({:event, key("right")}, basic_state(0))

      assert_receive {:slides_tui, :view, view}
      assert %{index: 1, total: 3, title: nil, notes: nil, theme: :dracula} = view
      assert view.next_title == "untitled"
    end

    test "a theme change pushes too, and the last slide has no next title" do
      {:noreply, _} = Host.update({:event, key("t")}, basic_state(2))
      assert_receive {:slides_tui, :view, %{theme: :midnight, next_title: nil}}
    end

    test "transitions that change nothing visible push nothing" do
      {:noreply, _} = Host.update({:info, :anything}, basic_state(0))
      {:noreply, _} = Host.update({:event, key("left")}, basic_state(0))
      refute_receive {:slides_tui, :view, _}
    end

    test "sync always pushes, carrying the notes and the next title" do
      state = interactive_state(talk_minutes: 30)
      {:noreply, ^state} = Host.update({:info, {:slides_tui, :sync}}, state)

      assert_receive {:slides_tui, :view, view}
      assert view.notes == "## Static\n\nThese are the notes."
      assert view.talk_minutes == 30
    end

    test "sync on an empty deck pushes an empty view" do
      {:noreply, _} = Host.update({:info, {:slides_tui, :sync}}, %State{slides: []})
      assert_receive {:slides_tui, :view, %{total: 0, title: nil, notes: nil}}
    end

    test "the timer starts with the deck" do
      {:ok, state, _} = Host.init(pattern: @basic_pattern)
      assert is_integer(state.timer_started_at)
    end

    test "restart_timer starts it over from now" do
      state = %{basic_state(1) | timer_started_at: System.monotonic_time(:millisecond) - 60_000}
      {:noreply, restarted} = Host.update({:info, {:slides_tui, :restart_timer}}, state)

      assert restarted.timer_started_at > state.timer_started_at
      assert_receive {:slides_tui, :view, %{timer_started_at: started}}
      assert started == restarted.timer_started_at
    end
  end

  describe "handle_info routing to the active slide" do
    test "info messages reach the slide's handle_info with its state" do
      state = interactive_state()
      # navigate to Ticker at index 3
      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("right")}, state)
      assert state.slide_states[3] == %{ticks: 0}

      {:noreply, state} = Host.update({:info, :tick}, state)
      {:noreply, state} = Host.update({:info, :tick}, state)
      assert state.slide_states[3] == %{ticks: 2}
    end

    test "info messages to an empty deck are ignored" do
      state = %State{slides: [], index: 0}
      assert {:noreply, ^state} = Host.update({:info, :anything}, state)
    end
  end

  describe "subscriptions/1" do
    test "returns [] when the active slide has no subscriptions" do
      assert Host.subscriptions(interactive_state()) == []
    end

    test "returns the active slide's subscriptions" do
      state = interactive_state()
      # navigate to Ticker at index 3
      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("right")}, state)

      assert [%ExRatatui.Subscription{id: :tick, kind: :interval}] =
               Host.subscriptions(state)
    end

    test "changes when index changes (subs follow the active slide)" do
      state = interactive_state()
      assert Host.subscriptions(state) == []

      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("right")}, state)
      {:noreply, state} = Host.update({:event, key("right")}, state)
      assert [_tick_sub] = Host.subscriptions(state)

      {:noreply, state} = Host.update({:event, key("left")}, state)
      assert Host.subscriptions(state) == []
    end

    test "returns [] for an empty deck" do
      assert Host.subscriptions(%State{slides: [], index: 0}) == []
    end
  end

  describe "render/2" do
    test "titleless slide — Clear, body block (no title), slide widget, footer widgets" do
      widgets = Host.render(basic_state(0), @frame)

      assert [
               {%Clear{}, clear_rect},
               {%Block{borders: []}, ground_rect},
               {%Block{title: nil, border_type: :rounded}, body_rect},
               {%Paragraph{text: "intro"}, inner_rect},
               {%Paragraph{text: progress_text}, _},
               {%Paragraph{text: attr_text, alignment: :center}, _},
               {%Paragraph{}, _},
               {%Paragraph{}, _},
               {%Paragraph{}, _},
               {%Paragraph{}, _}
             ] = widgets

      assert clear_rect == %Rect{x: 0, y: 0, width: 80, height: 24}
      assert ground_rect == clear_rect
      assert body_rect == %Rect{x: 0, y: 0, width: 80, height: 23}
      assert inner_rect == %Rect{x: 1, y: 1, width: 78, height: 21}
      assert progress_text == " 1 / 3 "
      assert Enum.map_join(attr_text.spans, & &1.content) == " built with ex_ratatui "
    end

    test "titled slide — title sits in the block header, not a separate row" do
      state = %State{slides: [SlidesTui.Test.TitledSlide], index: 0}
      widgets = Host.render(state, @frame)

      assert [
               {%Clear{}, _},
               {%Block{borders: []}, _},
               {%Block{title: " Hello ", border_type: :rounded}, body_rect},
               {%Paragraph{text: "body"}, inner_rect}
               | footer_widgets
             ] = widgets

      assert body_rect == %Rect{x: 0, y: 0, width: 80, height: 23}
      assert inner_rect == %Rect{x: 1, y: 1, width: 78, height: 21}
      # progress + attribution + 4 hint chips
      assert length(footer_widgets) == 6
    end

    test "footer progress reflects the active slide's index" do
      widgets = Host.render(basic_state(2), @frame)
      [_clear, _ground, _body, _slide, {%Paragraph{text: progress_text}, _} | _rest] = widgets
      assert progress_text == " 3 / 3 "
    end

    test "empty deck — Clear, ground, then the placeholder Paragraph, no chrome block" do
      state = %State{slides: [], index: 0}
      widgets = Host.render(state, @frame)

      assert [{%Clear{}, _}, {%Block{borders: []}, _}, {%Paragraph{text: text}, _rect}] = widgets
      assert text =~ "No slides found"
    end

    test "passes per-slide state to the active slide's render/2" do
      state = interactive_state(start: 42)
      {:noreply, state} = Host.update({:event, key("right")}, state)

      widgets = Host.render(state, @frame)
      [_clear, _ground, _body, {%Paragraph{text: text}, _inner_rect} | _footer] = widgets
      assert text == "count: 42"
    end
  end

  describe "integration — running under test_mode" do
    test "starts, renders at least once, and exits cleanly on q" do
      {:ok, pid} =
        Host.start_link(name: nil, test_mode: {80, 24}, pattern: @basic_pattern)

      ref = Process.monitor(pid)

      snapshot = ExRatatui.Runtime.snapshot(pid)
      assert snapshot.mode == :reducer
      assert snapshot.render_count >= 1

      :ok = ExRatatui.Runtime.inject_event(pid, key("q"))
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
    end

    test "starts with empty deck, renders placeholder, and quits cleanly on q" do
      {:ok, pid} =
        Host.start_link(
          name: nil,
          test_mode: {80, 24},
          pattern: "test/support/fixtures/nope_does_not_exist/*.ex"
        )

      ref = Process.monitor(pid)

      snapshot = ExRatatui.Runtime.snapshot(pid)
      assert snapshot.render_count >= 1

      :ok = ExRatatui.Runtime.inject_event(pid, key("q"))
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
    end

    test "talk deck under lib/slides/ navigates through every slide without crashing" do
      {:ok, pid} = Host.start_link(name: nil, test_mode: {120, 36})
      ref = Process.monitor(pid)

      assert ExRatatui.Runtime.snapshot(pid).render_count >= 1

      # advance through the whole deck, mounting every slide on the way
      presses = length(SlidesTui.Deck.discover()) - 1
      for _ <- 1..presses, do: :ok = ExRatatui.Runtime.inject_event(pid, key("right"))

      :ok = ExRatatui.Runtime.inject_event(pid, key("q"))
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
    end

    test "runtime arms the active slide's subscriptions and tears them down on nav" do
      {:ok, pid} =
        Host.start_link(name: nil, test_mode: {80, 24}, pattern: @interactive_pattern)

      ref = Process.monitor(pid)

      # Static at index 0 — no subscriptions
      assert ExRatatui.Runtime.snapshot(pid).subscription_count == 0

      # Navigate to Ticker at index 3
      for _ <- 1..3, do: :ok = ExRatatui.Runtime.inject_event(pid, key("right"))

      snapshot = ExRatatui.Runtime.snapshot(pid)
      assert snapshot.subscription_count == 1
      assert [%{id: :tick, active?: true}] = snapshot.subscriptions

      # Navigate away — subscription torn down
      :ok = ExRatatui.Runtime.inject_event(pid, key("left"))
      assert ExRatatui.Runtime.snapshot(pid).subscription_count == 0

      :ok = ExRatatui.Runtime.inject_event(pid, key("q"))
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
    end
  end
end
