defmodule SlidesTui.State do
  @moduledoc """
  Host state for a running SlidesTui deck.

    * `:slides` — ordered list of slide modules from `Deck.discover/1`
    * `:index` — 0-based index of the active slide
    * `:slide_states` — `%{index => per_slide_state}`; lazily populated
      on first visit and preserved across navigations
    * `:notes_open?` — whether the notes popup is visible
    * `:theme` — the active `SlidesTui.Theme` name; `t` cycles it
    * `:min_size` — `{cols, rows}` the deck needs; a smaller frame shows
      a "terminal too small" screen instead of clipped slides
    * `:opts` — the opts the host was started with; passed verbatim
      to every slide's `mount/1`
  """

  defstruct slides: [],
            index: 0,
            slide_states: %{},
            notes_open?: false,
            theme: :dracula,
            min_size: {0, 0},
            opts: []

  @type t :: %__MODULE__{
          slides: [module()],
          index: non_neg_integer(),
          slide_states: %{non_neg_integer() => term()},
          notes_open?: boolean(),
          theme: atom(),
          min_size: {non_neg_integer(), non_neg_integer()},
          opts: keyword()
        }
end
