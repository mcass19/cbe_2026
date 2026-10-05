defmodule SlidesTuiTest do
  use ExUnit.Case, async: true

  test "module is defined" do
    assert Code.ensure_loaded?(SlidesTui)
  end

  test "child_spec/1 delegates to Host" do
    assert %{id: SlidesTui.Host, start: {SlidesTui.Host, :start_link, _}} =
             SlidesTui.child_spec([])
  end

  test "start_link/1 delegates to Host and quits cleanly on q" do
    {:ok, pid} =
      SlidesTui.start_link(
        name: nil,
        test_mode: {80, 24},
        pattern: "test/support/fixtures/deck_basic/*.ex"
      )

    ref = Process.monitor(pid)
    snapshot = ExRatatui.Runtime.snapshot(pid)
    assert snapshot.render_count >= 1

    :ok =
      ExRatatui.Runtime.inject_event(pid, %ExRatatui.Event.Key{code: "q", kind: "press"})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
  end

  test "run/1 blocks until the host exits and returns :ok" do
    parent = self()
    name = :"slides_tui_run_test_#{System.unique_integer([:positive])}"

    runner =
      spawn_link(fn ->
        result =
          SlidesTui.run(
            name: name,
            test_mode: {80, 24},
            pattern: "test/support/fixtures/deck_basic/*.ex"
          )

        send(parent, {:run_returned, result})
      end)

    ref = Process.monitor(runner)

    # Wait until the named host is alive and has rendered at least once.
    pid = wait_until_registered(name)
    assert ExRatatui.Runtime.snapshot(pid).render_count >= 1

    :ok =
      ExRatatui.Runtime.inject_event(pid, %ExRatatui.Event.Key{code: "q", kind: "press"})

    assert_receive {:run_returned, :ok}, 2_000
    assert_receive {:DOWN, ^ref, :process, ^runner, :normal}, 2_000
  end

  test "run/1 serves the presenter view while the deck runs" do
    parent = self()
    name = :"slides_tui_presenter_run_test_#{System.unique_integer([:positive])}"

    spawn_link(fn ->
      result =
        SlidesTui.run(
          name: name,
          test_mode: {80, 24},
          presenter_port: 0,
          pattern: "test/support/fixtures/deck_basic/*.ex"
        )

      send(parent, {:run_returned, result})
    end)

    # run/1 starts the daemon before the host and stops it on the way
    # out; returning :ok means both went through
    pid = wait_until_registered(name)

    :ok =
      ExRatatui.Runtime.inject_event(pid, %ExRatatui.Event.Key{code: "q", kind: "press"})

    assert_receive {:run_returned, :ok}, 2_000
  end

  defp wait_until_registered(name) do
    Enum.find_value(1..100, fn _ ->
      case Process.whereis(name) do
        nil ->
          Process.sleep(10)
          nil

        pid ->
          pid
      end
    end) || flunk("host #{inspect(name)} never registered")
  end
end
