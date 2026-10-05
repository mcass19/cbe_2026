defmodule SlidesTui.Presenter do
  @moduledoc """
  The presenter view: the active slide's speaker notes, the next slide's
  title, a talk timer and the wall clock, following a running deck.

  It is a reducer-runtime `ExRatatui.App` served over SSH (see
  `start_daemon/2`), so the deck can fill the projector while the notes
  sit on the laptop screen:

      $ mix slides.tui                 # big screen
      $ ssh -p 2223 localhost          # laptop screen

  Each SSH session registers in `SlidesTui.Registry` under
  `{:presenter, host}` and gets a fresh view from the host on every
  slide change. The navigation keys drive the deck from here too, so a
  clicker works whichever window has focus:

    * `←` / `h` / `page up` — prev slide
    * `→` / `l` / `space` / `page down` — next slide
    * `↑` / `k` and `↓` / `j` — scroll the notes; a new slide starts
      at the top
    * `s` — restart the talk timer from zero
    * `q` — close this view (the deck keeps running)

  The timer starts with the deck; `s` restarts it. With `:talk_minutes`
  set on the host it shows the talk length too, turns violet in the last
  five minutes and magenta once over time.

  ## Options

    * `:host` — the deck's host pid. Defaults to the host registered in
      `SlidesTui.Registry` under `:host`.
  """

  use ExRatatui.App, runtime: :reducer

  alias ExRatatui.Event.{Key, Resize}
  alias ExRatatui.Frame
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Subscription
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.{Block, Clear, Markdown, Paragraph}
  alias ExRatatui.Widgets.Block.Title
  alias SlidesTui.Theme

  # Same keys as the deck, so the clicker behaves the same in both windows.
  @next_keys ["right", "l", " ", "page_down"]
  @prev_keys ["left", "h", "page_up"]
  @warn_ms 5 * 60_000
  @hints " ←/→ slides · ↑/↓ scroll · s restart timer · q close "

  defstruct host: nil, view: nil, now: 0, clock: {0, 0}, scroll: 0, size: {80, 24}

  @type view :: %{
          index: non_neg_integer(),
          total: non_neg_integer(),
          title: String.t() | nil,
          notes: String.t() | nil,
          next_title: String.t() | nil,
          theme: atom(),
          timer_started_at: integer() | nil,
          talk_minutes: pos_integer() | nil
        }

  @type t :: %__MODULE__{
          host: pid() | nil,
          view: view() | :stopped | nil,
          now: integer(),
          clock: {0..23, 0..59},
          scroll: non_neg_integer(),
          size: {non_neg_integer(), non_neg_integer()}
        }

  @doc """
  Starts the SSH daemon that serves this view on `port`, bound to
  `127.0.0.1` with no authentication.

  Loopback-only is what makes skipping auth safe: only the laptop
  running the deck can connect. `app_opts` reach every session's
  `init/1` (tests pass `:host` there). The host key is generated once
  under `priv/ssh/` and reused, so `ssh` only asks to trust it the
  first time.
  """
  @spec start_daemon(:inet.port_number(), keyword()) :: GenServer.on_start()
  def start_daemon(port, app_opts \\ []) do
    ExRatatui.SSH.Daemon.start_link(
      mod: __MODULE__,
      port: port,
      name: nil,
      ip: {127, 0, 0, 1},
      no_auth_needed: true,
      auto_host_key: true,
      app_opts: app_opts
    )
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      host: Keyword.get_lazy(opts, :host, &find_host/0),
      size: {Keyword.get(opts, :width, 80), Keyword.get(opts, :height, 24)}
    }

    {:ok, state |> tick() |> follow()}
  end

  defp find_host do
    case Registry.lookup(SlidesTui.Registry, :host) do
      [{pid, _} | _] -> pid
      [] -> nil
    end
  end

  defp follow(%__MODULE__{host: nil} = state), do: %{state | view: :stopped}

  defp follow(%__MODULE__{host: host} = state) do
    Process.monitor(host)
    {:ok, _} = Registry.register(SlidesTui.Registry, {:presenter, host}, nil)
    send(host, {:slides_tui, :sync})
    state
  end

  @impl true
  def update({:info, {:slides_tui, :view, view}}, state) do
    scroll = if same_slide?(state.view, view), do: state.scroll, else: 0
    {:noreply, clamp_scroll(%{state | view: view, scroll: scroll})}
  end

  def update({:event, %Resize{width: w, height: h}}, state),
    do: {:noreply, clamp_scroll(%{state | size: {w, h}})}

  def update({:info, :tick}, state), do: {:noreply, tick(state)}

  def update({:info, {:DOWN, _ref, :process, host, _reason}}, %__MODULE__{host: host} = state),
    do: {:noreply, %{state | view: :stopped}}

  def update({:event, %Key{code: "q", kind: "press"}}, state), do: {:stop, state}

  def update({:event, %Key{code: code, kind: "press"}}, state) when code in @next_keys,
    do: tell_host(state, :next)

  def update({:event, %Key{code: code, kind: "press"}}, state) when code in @prev_keys,
    do: tell_host(state, :prev)

  def update({:event, %Key{code: code, kind: "press"}}, state) when code in ["down", "j"],
    do: {:noreply, clamp_scroll(%{state | scroll: state.scroll + 1})}

  def update({:event, %Key{code: code, kind: "press"}}, state) when code in ["up", "k"],
    do: {:noreply, clamp_scroll(%{state | scroll: state.scroll - 1})}

  def update({:event, %Key{code: "s", kind: "press"}}, state),
    do: tell_host(state, :restart_timer)

  def update(_msg, state), do: {:noreply, state}

  defp same_slide?(%{index: index}, %{index: index}), do: true
  defp same_slide?(_old, _new), do: false

  defp clamp_scroll(state),
    do: %{state | scroll: state.scroll |> min(max_scroll(state)) |> max(0)}

  # How far the notes scroll before their last line is on screen. The
  # Markdown widget wraps in Rust, so the height is an estimate: each
  # line wraps at a few cells short of the inner width, which errs on
  # the side of reaching the end. The frame takes 2 columns of border
  # and 4 of padding, 3 rows of border and padding.
  defp max_scroll(%__MODULE__{view: %{notes: notes}, size: {w, h}}) when is_binary(notes) do
    width = max(w - 6 - 4, 1)

    rows =
      notes
      |> String.split("\n")
      |> Enum.map(&max(1, ceil(String.length(&1) / width)))
      |> Enum.sum()

    max(rows - (h - 3), 0)
  end

  defp max_scroll(_state), do: 0

  defp tell_host(%__MODULE__{view: :stopped} = state, _msg), do: {:noreply, state}

  defp tell_host(%__MODULE__{host: host} = state, msg) do
    send(host, {:slides_tui, msg})
    {:noreply, state}
  end

  defp tick(state) do
    {_date, {h, m, _s}} = :calendar.local_time()
    %{state | now: System.monotonic_time(:millisecond), clock: {h, m}}
  end

  @impl true
  def subscriptions(_state), do: [Subscription.interval(:clock, 500, :tick)]

  @impl true
  def render(%__MODULE__{view: view} = state, %Frame{width: w, height: h}) do
    theme = Theme.fetch!(theme_name(view))
    area = %Rect{x: 0, y: 0, width: w, height: h}
    ground = %Block{style: %Style{fg: theme.text, bg: theme.ground}}

    [{%Clear{}, area}, {ground, area}, {body(state, frame_block(state, theme), theme), area}]
  end

  defp theme_name(%{theme: theme}), do: theme
  defp theme_name(_waiting_or_stopped), do: Theme.default()

  defp body(%__MODULE__{view: nil}, block, theme),
    do: message("waiting for the deck…", block, theme)

  defp body(%__MODULE__{view: :stopped}, block, theme),
    do: message("the deck isn't running · q closes this view", block, theme)

  defp body(%__MODULE__{view: %{notes: nil}}, block, theme),
    do: message("no notes for this slide", block, theme)

  defp body(%__MODULE__{view: %{notes: notes}, scroll: scroll}, block, _theme),
    do: %Markdown{content: notes, block: block, scroll: {scroll, 0}}

  defp message(text, block, theme),
    do: %Paragraph{
      text: text,
      style: %Style{fg: theme.subtle, modifiers: [:italic]},
      block: block
    }

  defp frame_block(%__MODULE__{view: view} = state, theme) do
    %Block{
      borders: [:all],
      border_type: :rounded,
      border_style: %Style{fg: theme.accent},
      style: %Style{fg: theme.text},
      padding: {2, 2, 1, 0},
      title: slide_title(view, theme),
      titles: [
        %Title{content: Line.new([timer(state, theme), clock(state, theme)]), alignment: :right},
        %Title{content: next_title(view, theme), position: :bottom},
        %Title{content: more(state, theme), position: :bottom, alignment: :center},
        %Title{
          content: Span.new(@hints, style: %Style{fg: theme.muted}),
          position: :bottom,
          alignment: :right
        }
      ]
    }
  end

  # Long notes say so on the bottom border while there's more below.
  defp more(state, theme) do
    if state.scroll < max_scroll(state),
      do:
        Span.new(" ↓ more ",
          style: %Style{fg: theme.ground, bg: theme.violet, modifiers: [:bold]}
        ),
      else: ""
  end

  defp slide_title(%{total: total} = view, theme) when total > 0 do
    progress = Span.new(" #{view.index + 1} / #{total} ", style: chip(theme))
    Line.new([progress | title_spans(view.title)])
  end

  defp slide_title(_view, _theme), do: " presenter "

  defp title_spans(nil), do: []
  defp title_spans(title), do: [Span.new(" #{title} ", style: %Style{modifiers: [:bold]})]

  defp next_title(%{next_title: title}, theme) when is_binary(title) do
    Line.new([
      Span.new(" next → ", style: %Style{fg: theme.muted}),
      Span.new("#{title} ", style: %Style{fg: theme.cyan})
    ])
  end

  defp next_title(%{total: total}, theme) when total > 0,
    do: Span.new(" last slide ", style: %Style{fg: theme.muted})

  defp next_title(_view, _theme), do: ""

  defp timer(%__MODULE__{view: %{timer_started_at: started} = view, now: now}, theme)
       when is_integer(started) do
    elapsed = max(now - started, 0)

    case view.talk_minutes do
      nil ->
        Span.new(" #{mmss(elapsed)} ", style: chip(theme))

      minutes ->
        target = minutes * 60_000

        Span.new(" #{mmss(elapsed)} / #{mmss(target)} ",
          style: timer_style(target - elapsed, theme)
        )
    end
  end

  defp timer(_state, theme), do: Span.new(" --:-- ", style: chip(theme))

  defp timer_style(left, theme) when left > @warn_ms, do: chip(theme)

  defp timer_style(left, theme) when left > 0,
    do: %Style{fg: theme.ground, bg: theme.violet, modifiers: [:bold]}

  defp timer_style(_over, theme),
    do: %Style{fg: theme.ground, bg: theme.accent, modifiers: [:bold]}

  defp clock(%__MODULE__{clock: {h, m}}, theme),
    do: Span.new(" #{pad(h)}:#{pad(m)} ", style: %Style{fg: theme.muted})

  defp mmss(ms) do
    seconds = div(ms, 1000)
    "#{pad(div(seconds, 60))}:#{pad(rem(seconds, 60))}"
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  defp chip(theme), do: %Style{fg: theme.chip_fg, bg: theme.chip_bg, modifiers: [:bold]}
end
