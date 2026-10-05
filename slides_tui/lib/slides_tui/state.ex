defmodule SlidesTui.State do
  @moduledoc """
  Host state for a running SlidesTui deck.

    * `:slides` — ordered list of slide modules from `Deck.discover/1`
    * `:index` — 0-based index of the active slide
    * `:slide_states` — `%{index => per_slide_state}`; lazily populated
      on first visit and preserved across navigations
    * `:theme` — the active `SlidesTui.Theme` name; `t` cycles it
    * `:min_size` — `{cols, rows}` the deck needs; a smaller frame shows
      a "terminal too small" screen instead of clipped slides
    * `:timer_started_at` — monotonic milliseconds when the talk timer
      started (the deck's start, or the last restart)
    * `:talk_minutes` — the talk's length, shown next to the timer in the
      presenter view, or `nil` for a plain elapsed clock
    * `:opts` — the opts the host was started with; passed verbatim
      to every slide's `mount/1`
  """

  defstruct slides: [],
            index: 0,
            slide_states: %{},
            theme: :dracula,
            min_size: {0, 0},
            timer_started_at: nil,
            talk_minutes: nil,
            opts: []

  @type t :: %__MODULE__{
          slides: [module()],
          index: non_neg_integer(),
          slide_states: %{non_neg_integer() => term()},
          theme: atom(),
          min_size: {non_neg_integer(), non_neg_integer()},
          timer_started_at: integer() | nil,
          talk_minutes: pos_integer() | nil,
          opts: keyword()
        }
end
