defmodule TuisEverywhere.Slides.Observability do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "In production"

  def notes do
    """
    - test: two levels. widget level, headless terminal + draw + read the buffer. app level, test_mode {w, h}: real runtime, virtual terminal, zero tty, inject events, snapshot cells, never escapes. async true, milliseconds each
    - the parity suite: the same scenario against local, ssh, distributed through one driver module. that is the evidence for "same module everywhere", not a slogan

    - debug: three layers, least invasive first. Runtime.snapshot/1: mode, render count, subscriptions, async commands in flight. enable_trace/2: ring buffer, 200 events, kinds message / render / command / subscription with monotonic ms -> pair a message to its render, spot the 40ms frame among the 2ms ones. last: draw into a headless buffer, even inside terminate/2
    - never IO.inspect in raw mode, route Logger to a file. vm killed and the shell is dazed: type reset blind

    - telemetry: five runtime spans (init, event, update, frame, transport connect), two library spans (image decode, code highlight), four events (session open/close, dropped frame, disconnect). frame stop carries widget_count -> p99 frame time by widget count is a one-liner. event vs update split answers "is it the keyboard or my tick". attach_default_logger, one call. opentelemetry pairs through the span context: render next to http and db in one timeline. examples/observability/telemetry.exs

    - perf: 16ms poll ~60fps, 33 for idle apps, 8 for games. draw and poll on DirtyIo, a slow frame never stalls a scheduler. slice before %List{}: 20 items cross the nif, not a million. render?: false when nothing visible changed. 0.13.1: nif 5.3 -> 4.6MB, raytrace 6% faster, lto for free

    - ship: last "where", someone else's machine, no erlang on it. burrito, 0.13: `mix ex_ratatui.gen.burrito --ci github`. patches mix.exs, drops a cli shim, scaffolds the release workflow, pins zig 0.16 (0.15 cannot link on macos tahoe). a release step fails the linux build if the nif is glibc instead of musl. ~21MB binary, first launch unpacks to a cache, then instant
    - burrito story if time: inside the binary the tui runs synchronously, burrito halts the node the moment boot returns, so an async start dies before the first frame
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Trust it, ship it", [
      "test — test_mode {w, h}: the real runtime on a virtual terminal, no TTY, async",
      "debug — runtime snapshot, a trace ring buffer, headless buffer inspection",
      "telemetry — spans on init / event / update / frame / connect, widget_count per frame",
      "perf — 16ms poll ≈ 60fps, draw + poll on DirtyIo, quiet frames near free",
      "ship — Burrito: one native binary per OS, no Erlang on the user's machine"
    ])
  end
end
