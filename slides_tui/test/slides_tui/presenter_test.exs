defmodule SlidesTui.PresenterTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Event.Key
  alias ExRatatui.Frame
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.{Block, Clear, Markdown, Paragraph}
  alias ExRatatui.Widgets.Block.Title
  alias SlidesTui.{Host, Presenter, Theme}

  @frame %Frame{width: 100, height: 30}

  defp key(code), do: %Key{code: code, kind: "press"}

  # The test process plays the host: init/1 registers under it and
  # sends it a sync.
  defp presenter(view \\ nil) do
    {:ok, state} = Presenter.init(host: self())
    assert_receive {:slides_tui, :sync}
    %{state | view: view}
  end

  defp view(overrides \\ []) do
    Map.merge(
      %{
        index: 4,
        total: 17,
        title: "Raster",
        notes: "- pixels, not cells",
        next_title: "Lobby",
        theme: :dracula,
        timer_started_at: nil,
        talk_minutes: nil
      },
      Map.new(overrides)
    )
  end

  defp text(%Line{spans: spans}), do: Enum.map_join(spans, & &1.content)
  defp text(%Span{content: content}), do: content
  defp text(string) when is_binary(string), do: string

  defp frame_block(state) do
    [{%Clear{}, _}, {%Block{borders: []}, _}, {body, _}] = Presenter.render(state, @frame)
    {body, body.block}
  end

  defp titles(%Block{title: title, titles: titles}),
    do: [text(title) | Enum.map(titles, fn %Title{content: c} -> text(c) end)]

  describe "init/1" do
    test "follows the given host and asks it for a view" do
      state = presenter()
      assert state.host == self()
      assert [{_pid, nil}] = Registry.lookup(SlidesTui.Registry, {:presenter, self()})
    end

    test "shows a stopped deck without a host" do
      {:ok, state} = Presenter.init(host: nil)
      assert state.view == :stopped
    end
  end

  describe "update/2" do
    test "takes the host's views" do
      {:noreply, state} = Presenter.update({:info, {:slides_tui, :view, view()}}, presenter())
      assert state.view == view()
    end

    test "navigation keys and s drive the host" do
      state = presenter(view())

      for code <- ["right", "l", " ", "page_down"] do
        assert {:noreply, ^state} = Presenter.update({:event, key(code)}, state)
        assert_receive {:slides_tui, :next}
      end

      for code <- ["left", "h", "page_up"] do
        assert {:noreply, ^state} = Presenter.update({:event, key(code)}, state)
        assert_receive {:slides_tui, :prev}
      end

      assert {:noreply, ^state} = Presenter.update({:event, key("s")}, state)
      assert_receive {:slides_tui, :restart_timer}
    end

    test "keys go nowhere once the deck has stopped" do
      state = %{presenter() | view: :stopped}
      assert {:noreply, ^state} = Presenter.update({:event, key("right")}, state)
      refute_receive {:slides_tui, :next}
    end

    test "the host going down stops the view; other monitors don't" do
      state = presenter(view())
      other = {:info, {:DOWN, make_ref(), :process, spawn(fn -> :ok end), :normal}}
      assert {:noreply, ^state} = Presenter.update(other, state)

      down = {:info, {:DOWN, make_ref(), :process, self(), :normal}}
      assert {:noreply, %{view: :stopped}} = Presenter.update(down, state)
    end

    test "tick refreshes the clocks, q closes, anything else is ignored" do
      state = %{presenter() | now: 0}
      assert {:noreply, %{now: now}} = Presenter.update({:info, :tick}, state)
      assert now != 0

      assert {:stop, ^state} = Presenter.update({:event, key("q")}, state)
      assert {:noreply, ^state} = Presenter.update({:event, key("x")}, state)
    end

    test "ticks every half second" do
      assert [%ExRatatui.Subscription{id: :clock, kind: :interval}] =
               Presenter.subscriptions(presenter())
    end
  end

  describe "render/2" do
    test "notes as markdown, slide and timer on top, next slide and keys below" do
      state = %{presenter(view()) | clock: {9, 5}}
      {body, block} = frame_block(state)

      assert %Markdown{content: "- pixels, not cells"} = body

      assert titles(block) == [
               " 5 / 17  Raster ",
               " --:--  09:05 ",
               " next → Lobby ",
               " ←/→ slides · s restart timer · q close "
             ]
    end

    test "paints in the deck's theme" do
      daylight = Theme.fetch!(:daylight)
      state = presenter(view(theme: :daylight))

      assert [_, {%Block{style: style}, _}, {%Markdown{block: block}, _}] =
               Presenter.render(state, @frame)

      assert {style.bg, block.border_style.fg} == {daylight.ground, daylight.accent}
    end

    test "elapsed time once the timer runs" do
      state = %{presenter(view(timer_started_at: 0)) | now: 754_900}
      {_body, block} = frame_block(state)
      assert [_, " 12:34  " <> _ | _] = titles(block)
    end

    test "with a talk length the timer shows both and warns near the end" do
      theme = Theme.fetch!(:dracula)
      state = presenter(view(timer_started_at: 0, talk_minutes: 40))

      styles =
        for elapsed <- [10 * 60_000, 36 * 60_000, 41 * 60_000] do
          {_body, %Block{titles: [%Title{content: %Line{spans: [timer | _]}} | _]}} =
            frame_block(%{state | now: elapsed})

          {timer.content, timer.style.bg}
        end

      assert styles == [
               {" 10:00 / 40:00 ", theme.chip_bg},
               {" 36:00 / 40:00 ", theme.violet},
               {" 41:00 / 40:00 ", theme.accent}
             ]
    end

    test "a slide without notes or title, and the last slide" do
      state = presenter(view(title: nil, notes: nil, next_title: nil, index: 16))
      {body, block} = frame_block(state)

      assert %Paragraph{text: "no notes for this slide"} = body
      assert [" 17 / 17 ", _, " last slide ", _] = titles(block)
    end

    test "waiting for the first view, a stopped deck, and an empty one" do
      assert {%Paragraph{text: "waiting for the deck…"}, block} = frame_block(presenter())
      assert [" presenter ", _, "", _] = titles(block)

      assert {%Paragraph{text: "the deck isn't running" <> _}, _} =
               frame_block(presenter(:stopped))

      empty = view(total: 0, index: 0, title: nil, notes: nil, next_title: nil)
      assert {%Paragraph{text: "no notes for this slide"}, _} = frame_block(presenter(empty))
    end
  end

  describe "with a running deck" do
    test "a presenter session follows the deck and drives it" do
      {:ok, host} =
        Host.start_link(
          name: nil,
          test_mode: {80, 24},
          pattern: "test/support/fixtures/deck_interactive/*.ex"
        )

      {:ok, presenter} = Presenter.start_link(name: nil, test_mode: {80, 24}, host: host)

      wait_for(fn -> app_state(presenter).view != nil end)
      :ok = ExRatatui.Runtime.inject_event(presenter, key("right"))

      wait_for(fn -> match?(%{index: 1}, app_state(presenter).view) end)
      assert app_state(host).index == 1

      ref = Process.monitor(presenter)
      :ok = ExRatatui.Runtime.inject_event(host, key("q"))
      wait_for(fn -> app_state(presenter).view == :stopped end)

      :ok = ExRatatui.Runtime.inject_event(presenter, key("q"))
      assert_receive {:DOWN, ^ref, :process, ^presenter, :normal}, 2_000
    end
  end

  describe "start_daemon/2" do
    test "serves on loopback with no auth" do
      {:ok, daemon} = Presenter.start_daemon(0, host: self())
      {:ok, ref} = ExRatatui.SSH.Daemon.daemon_ref(daemon)
      {:ok, info} = :ssh.daemon_info(ref)

      assert info[:ip] == {127, 0, 0, 1}

      {:ok, conn} =
        :ssh.connect(~c"127.0.0.1", info[:port],
          user: ~c"anyone",
          silently_accept_hosts: true,
          user_interaction: false,
          save_accepted_host: false
        )

      :ok = :ssh.close(conn)
      :ok = GenServer.stop(daemon)
    end
  end

  defp app_state(pid), do: :sys.get_state(pid).user_state

  defp wait_for(fun) do
    Enum.find_value(1..200, fn _ ->
      fun.() || (Process.sleep(10) && nil)
    end) || flunk("condition never held")
  end
end
