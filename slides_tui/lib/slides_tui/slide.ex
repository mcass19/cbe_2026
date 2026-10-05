defmodule SlidesTui.Slide do
  @moduledoc """
  Behaviour for a single slide in a SlidesTui deck.

  A slide is an Elixir module that returns terminal widgets from
  `render/2` for a given state and area. Slides can be purely static
  or hold per-slide state and react to events the host doesn't
  consume itself (navigation, notes toggle, quit).

  ## Required

    * `render/2` — return a list of `{widget, rect}` tuples drawn
      inside the body area the host passes in.

  ## Optional (defaults provided by `use SlidesTui.Slide`)

    * `mount/1` — called once the first time the slide becomes
      visible. Returns `{:ok, initial_state}`. Default: `{:ok, nil}`.
    * `handle_event/2` — receives events not claimed by the host.
      Returns `{:noreply, state}` or `{:stop, state}`. A `:stop`
      stops the whole deck. Default: no-op.
    * `handle_info/2` — receives info messages (subscription ticks,
      `send/2`, PubSub) routed to the active slide. Same return
      shape as `handle_event/2`. Default: no-op.
    * `subscriptions/1` — list of subscriptions the runtime keeps
      active while this slide is the active one; torn down on
      navigate-away. Default: `[]`.
    * `title/0` — string for the chrome header, or `nil` to skip
      the header row. Default: `nil`.
    * `notes/0` — markdown for the presenter view's notes, or
      `nil`. Default: `nil`.

  ## Example

      defmodule MyTalk.Slides.Intro do
        use SlidesTui.Slide
        alias ExRatatui.Widgets.BigText

        def title, do: "Welcome"
        def notes, do: "## Intro\\n- thank the audience"

        def render(_state, area) do
          [{%BigText{lines: ["Hello!"]}, area}]
        end
      end
  """

  @typedoc "Per-slide state. SlidesTui never inspects it."
  @type state :: term()

  @typedoc "Terminal events forwarded to a slide by the host."
  @type event ::
          ExRatatui.Event.Key.t()
          | ExRatatui.Event.Mouse.t()
          | ExRatatui.Event.Resize.t()

  @doc """
  Returns the widgets to draw inside `area`.

  Called after every state change while this slide is active.
  """
  @callback render(state(), ExRatatui.Layout.Rect.t()) ::
              [{ExRatatui.widget(), ExRatatui.Layout.Rect.t()}]

  @doc """
  Called once the first time the slide becomes active.

  Receives the opts passed to the host. Subsequent visits reuse the
  state returned here (mutated through `handle_event/2`).
  """
  @callback mount(opts :: keyword()) :: {:ok, state()}

  @doc """
  Handles an event the host did not consume.

  Returning `{:stop, state}` stops the deck.
  """
  @callback handle_event(event(), state()) ::
              {:noreply, state()} | {:stop, state()}

  @doc """
  Handles a non-event message routed to the active slide.

  These arrive from subscription firings, `send/2`, and PubSub
  broadcasts. Same return shape as `handle_event/2`.
  """
  @callback handle_info(msg :: term(), state()) ::
              {:noreply, state()} | {:stop, state()}

  @doc """
  Subscriptions the runtime should keep active while this slide is
  the active one. The host tears them down on navigate-away.
  """
  @callback subscriptions(state()) :: [ExRatatui.Subscription.t()]

  @doc """
  Optional chrome-header title. `nil` skips the header.
  """
  @callback title() :: String.t() | nil

  @doc """
  Optional speaker notes (markdown). `nil` makes `n` a no-op while
  this slide is active.
  """
  @callback notes() :: String.t() | nil

  @optional_callbacks [
    mount: 1,
    handle_event: 2,
    handle_info: 2,
    subscriptions: 1,
    title: 0,
    notes: 0
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour SlidesTui.Slide

      @doc false
      def mount(_opts), do: {:ok, nil}

      @doc false
      def handle_event(_event, state), do: {:noreply, state}

      @doc false
      def handle_info(_msg, state), do: {:noreply, state}

      @doc false
      def subscriptions(_state), do: []

      @doc false
      def title, do: nil

      @doc false
      def notes, do: nil

      defoverridable mount: 1,
                     handle_event: 2,
                     handle_info: 2,
                     subscriptions: 1,
                     title: 0,
                     notes: 0
    end
  end
end
