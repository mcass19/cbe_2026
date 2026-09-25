defmodule SlidesTui.Host do
  @moduledoc """
  The reducer-runtime `ExRatatui.App` that runs a SlidesTui deck.

  Discovers slides via `SlidesTui.Deck.discover/1`, mounts slide 0 on
  startup (and the rest lazily on first visit), renders the active
  slide inside a rounded chrome (magenta border, optional title in the
  block header, footer with a progress chip, one chip per key hint,
  and a small attribution), and routes input:

    * `←` / `h` / `page up` — prev slide (clamped at 0)
    * `→` / `l` / `space` / `page down` — next slide (clamped at the
      last slide). Page up/down and space are what presentation
      clickers emit, so the deck advances from a clicker untouched.
    * `q` — stop the deck
    * `n` — toggle notes popup (no-op when slide's `notes/0` is nil)
    * `t` — cycle the colour theme (see `SlidesTui.Theme`)
    * anything else — delegated to the active slide's
      `handle_event/2` (terminal events) or `handle_info/2` (info
      messages); a `{:stop, _}` from the slide stops the whole deck

  Per-slide state is preserved across navigations. The active slide's
  `subscriptions/1` is exposed to the runtime, which arms them on
  entry and tears them down on navigate-away.

  ## Options

    * `:pattern` — glob forwarded to `Deck.discover/1`. Defaults to
      `"lib/slides/*.ex"`.
    * `:theme` — the starting `SlidesTui.Theme` name. Defaults to
      `SlidesTui.Theme.default/0`.
    * `:min_size` — `{cols, rows}` the deck needs. Below it the host
      shows a "terminal too small" screen with the numbers instead of
      silently clipping slides. Defaults to `{0, 0}` (no guard).

  Plus every option recognised by `ExRatatui.App`
  (`:transport`, `:name`, `:test_mode`, `:poll_interval`, …). The full
  opts list is also passed to each slide's `mount/1`.

  ### Shutdown

  Pressing `q` (or any slide returning `{:stop, _}` from `handle_event/2`
  / `handle_info/2`) transitions the reducer to `{:stop, state}`, which
  shuts the host supervision tree down cleanly. Standalone callers
  (e.g. `mix slides.tui`) typically wrap `start_link/1` in a
  `Process.monitor/1` and unblock on the `:DOWN` message — see
  `SlidesTui.run/1`.
  """

  use ExRatatui.App, runtime: :reducer

  alias ExRatatui.Event.Key
  alias ExRatatui.Frame
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Widgets.{Block, Clear, Paragraph}
  alias SlidesTui.{Chrome, Deck, NotesPopup, PlaceholderSlide, State, Theme}

  @impl true
  def init(opts) do
    slides = Deck.discover(Keyword.take(opts, [:pattern]))

    state =
      mount_if_needed(%State{
        slides: slides,
        theme: Theme.fetch!(Keyword.get(opts, :theme, Theme.default())).name,
        min_size: Keyword.get(opts, :min_size, {0, 0}),
        opts: opts
      })

    # Ask the runtime to probe the local terminal once and cache the best
    # image protocol (Kitty / Sixel / iTerm2 / Halfblocks) on the
    # terminal_ref. Without this, `protocol: :auto` images fall back to
    # halfblocks and look pixelated even on protocol-capable terminals.
    # Soft-fails silently on no TTY; skipped under `test_mode: {w, h}`.
    {:ok, state, probe_image_protocol: true}
  end

  @impl true
  def update({:event, %Key{code: "q", kind: "press"}}, state),
    do: {:stop, state}

  def update({:event, %Key{code: code, kind: "press"}}, %State{slides: slides, index: i} = state)
      when code in ["right", "l", " ", "page_down"] do
    last = length(slides) - 1
    {:noreply, %{state | index: max(0, min(i + 1, last))} |> mount_if_needed()}
  end

  def update({:event, %Key{code: code, kind: "press"}}, %State{index: i} = state)
      when code in ["left", "h", "page_up"] do
    {:noreply, %{state | index: max(i - 1, 0)} |> mount_if_needed()}
  end

  def update({:event, %Key{code: "n", kind: "press"}}, %State{slides: [_ | _]} = state) do
    active = Enum.at(state.slides, state.index)

    case active.notes() do
      nil -> {:noreply, state}
      _ -> {:noreply, %{state | notes_open?: not state.notes_open?}}
    end
  end

  def update({:event, %Key{code: "t", kind: "press"}}, %State{theme: theme} = state),
    do: {:noreply, %{state | theme: Theme.next(theme)}}

  def update({:event, _event}, %State{slides: []} = state),
    do: {:noreply, state}

  def update({:info, _msg}, %State{slides: []} = state),
    do: {:noreply, state}

  def update({:event, event}, %State{} = state),
    do: dispatch(state, :handle_event, event)

  def update({:info, msg}, %State{} = state),
    do: dispatch(state, :handle_info, msg)

  def update(_msg, state),
    do: {:noreply, state}

  @impl true
  def subscriptions(%State{slides: []}), do: []

  def subscriptions(%State{slides: slides, index: index, slide_states: states}) do
    active = Enum.at(slides, index)
    active.subscriptions(Map.get(states, index))
  end

  # Every frame starts from the theme's own ground: a Clear, then a
  # borderless Block that paints ground + text colour over the whole
  # frame. Widgets drawn on top only patch the colours they set, so
  # nothing shows the terminal's background or foreground through.
  # The theme is also put in the process dictionary for the slide
  # helpers, which render inside this same process.
  @impl true
  def render(%State{theme: theme} = state, %Frame{width: w, height: h}) do
    :ok = Theme.put(theme)
    theme = Theme.current()
    area = %Rect{x: 0, y: 0, width: w, height: h}
    ground = %Block{style: %Style{fg: theme.text, bg: theme.ground}}

    [{%Clear{}, area}, {ground, area} | render_frame(state, area, theme)]
  end

  defp render_frame(%State{slides: []}, area, _theme), do: PlaceholderSlide.render(nil, area)

  defp render_frame(%State{min_size: {min_w, min_h}}, %Rect{width: w, height: h} = area, theme)
       when w < min_w or h < min_h,
       do: too_small(area, {min_w, min_h}, theme)

  defp render_frame(
         %State{
           slides: slides,
           index: index,
           slide_states: states,
           notes_open?: notes_open?
         },
         area,
         theme
       ) do
    active = Enum.at(slides, index)
    title = active.title()
    notes = active.notes()

    %{body: body_rect, inner: inner_rect, footer: footer_rect} = Chrome.layout(area)

    slide_widgets = active.render(Map.get(states, index), inner_rect)

    popup_widgets =
      if notes_open? and not is_nil(notes) do
        NotesPopup.overlay(notes, area, theme)
      else
        []
      end

    [
      {Chrome.body_block(title, theme), body_rect}
      | slide_widgets ++ Chrome.footer(index, length(slides), footer_rect, theme) ++ popup_widgets
    ]
  end

  # Slides are laid out for a minimum grid; below it they clip without
  # a word. Say so instead, with both sizes, so the font can be tuned
  # at the AV check until the real deck appears.
  defp too_small(%Rect{width: w, height: h} = area, {min_w, min_h}, theme) do
    lines = [
      "terminal is #{w}×#{h}, the deck needs #{min_w}×#{min_h}",
      "",
      "shrink the font (ctrl+-) or grow the window"
    ]

    rect = %Rect{area | y: area.y + max(div(h - length(lines), 2), 0), height: length(lines)}

    [
      {%Paragraph{
         text: Enum.join(lines, "\n"),
         alignment: :center,
         style: %Style{fg: theme.subtle}
       }, rect}
    ]
  end

  defp mount_if_needed(%State{slides: []} = state), do: state

  defp mount_if_needed(%State{slides: slides, index: i, slide_states: states, opts: opts} = state) do
    if Map.has_key?(states, i) do
      state
    else
      active = Enum.at(slides, i)
      {:ok, slide_state} = active.mount(opts)
      %{state | slide_states: Map.put(states, i, slide_state)}
    end
  end

  defp dispatch(state, callback, arg) do
    active = Enum.at(state.slides, state.index)
    slide_state = Map.get(state.slide_states, state.index)

    case apply(active, callback, [arg, slide_state]) do
      {:noreply, new_slide_state} ->
        {:noreply, put_slide_state(state, new_slide_state)}

      {:stop, new_slide_state} ->
        {:stop, put_slide_state(state, new_slide_state)}
    end
  end

  defp put_slide_state(%State{} = state, slide_state) do
    %{state | slide_states: Map.put(state.slide_states, state.index, slide_state)}
  end
end
