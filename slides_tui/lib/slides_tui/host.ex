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
    * anything else — delegated to the active slide's
      `handle_event/2` (terminal events) or `handle_info/2` (info
      messages); a `{:stop, _}` from the slide stops the whole deck

  Per-slide state is preserved across navigations. The active slide's
  `subscriptions/1` is exposed to the runtime, which arms them on
  entry and tears them down on navigate-away.

  ## Options

    * `:pattern` — glob forwarded to `Deck.discover/1`. Defaults to
      `"lib/slides/*.ex"`.

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
  alias ExRatatui.Widgets.Clear
  alias SlidesTui.{Chrome, Deck, NotesPopup, PlaceholderSlide, State}

  @impl true
  def init(opts) do
    slides = Deck.discover(Keyword.take(opts, [:pattern]))
    state = mount_if_needed(%State{slides: slides, opts: opts})

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

  @impl true
  def render(%State{slides: []}, %Frame{width: w, height: h}) do
    area = %Rect{x: 0, y: 0, width: w, height: h}
    [{%Clear{}, area} | PlaceholderSlide.render(nil, area)]
  end

  def render(
        %State{
          slides: slides,
          index: index,
          slide_states: states,
          notes_open?: notes_open?
        },
        %Frame{width: w, height: h}
      ) do
    area = %Rect{x: 0, y: 0, width: w, height: h}
    active = Enum.at(slides, index)
    title = active.title()
    notes = active.notes()

    %{body: body_rect, inner: inner_rect, footer: footer_rect} = Chrome.layout(area)

    slide_widgets = active.render(Map.get(states, index), inner_rect)

    popup_widgets =
      if notes_open? and not is_nil(notes) do
        NotesPopup.overlay(notes, area)
      else
        []
      end

    [
      {%Clear{}, area},
      {Chrome.body_block(title), body_rect}
      | slide_widgets ++ Chrome.footer(index, length(slides), footer_rect) ++ popup_widgets
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
