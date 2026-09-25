defmodule SlidesTui.Theme do
  @moduledoc """
  The deck's colour palettes, one struct of named roles per theme.

  The deck paints every colour itself, background included, so the
  terminal's own theme never leaks in: switching Ghostty from dark to
  light (or presenting from a different machine) leaves the slides
  untouched, and a theme switch in the deck recolours everything.

  Roles:

    * `:ground` — the background every cell sits on
    * `:text` — body text and headlines
    * `:subtle` — secondary text (subtitles, placeholder hints)
    * `:muted` — the quietest chrome (the footer's "built with", stars)
    * `:accent` — Code BEAM magenta: the slide border, the 3D cube
    * `:violet` — in-slide accents: bullet markers, prompts, captions
    * `:cyan` — names to look up: packages, atoms, modules, links
    * `:chip_bg` / `:chip_fg` — footer chips and the notes popup
    * `:code_theme` — the `CodeBlock` syntax theme that sits on `:ground`

  Themes:

    * `:dracula` — the default. Matches the Dracula terminal theme the
      deck was designed on, so it looks exactly as before themes existed.
    * `:midnight` — a near-black ground with slightly brighter accents,
      for projectors that lift blacks and turn Dracula's grey ground
      into mush.
    * `:daylight` — an off-white ground with deeper accents for brightly
      lit rooms, where dark slides wash out. The ground is the
      `base16-ocean.light` code theme's own background, so code blocks
      sit flush.

  The host puts the active theme in its process dictionary before each
  frame (`put/1`), and slide helpers read it back with `current/0`.
  Slides render inside the host process, so no slide needs a theme
  argument; outside a running host `current/0` falls back to the
  default.
  """

  @enforce_keys [
    :name,
    :ground,
    :text,
    :subtle,
    :muted,
    :accent,
    :violet,
    :cyan,
    :chip_bg,
    :chip_fg,
    :code_theme
  ]
  defstruct @enforce_keys

  @type rgb :: {:rgb, 0..255, 0..255, 0..255}

  @type t :: %__MODULE__{
          name: atom(),
          ground: rgb(),
          text: rgb(),
          subtle: rgb(),
          muted: rgb(),
          accent: rgb(),
          violet: rgb(),
          cyan: rgb(),
          chip_bg: rgb(),
          chip_fg: rgb(),
          code_theme: atom()
        }

  @default :dracula
  @key {__MODULE__, :current}

  @themes %{
    # Dracula's own values where the deck used to inherit them from the
    # terminal (ground, text, the grey of "built with", the dim
    # subtitle), plus the deck's accents as they were.
    dracula: %{
      ground: {:rgb, 40, 42, 54},
      text: {:rgb, 248, 248, 242},
      subtle: {:rgb, 165, 165, 161},
      muted: {:rgb, 98, 114, 164},
      accent: {:rgb, 225, 31, 193},
      violet: {:rgb, 167, 139, 250},
      cyan: {:rgb, 139, 233, 253},
      chip_bg: {:rgb, 58, 62, 78},
      chip_fg: {:rgb, 248, 248, 242},
      code_theme: :base16_ocean_dark
    },
    midnight: %{
      ground: {:rgb, 13, 14, 20},
      text: {:rgb, 242, 242, 240},
      subtle: {:rgb, 170, 170, 168},
      muted: {:rgb, 128, 138, 176},
      accent: {:rgb, 240, 70, 212},
      violet: {:rgb, 183, 160, 255},
      cyan: {:rgb, 128, 236, 255},
      chip_bg: {:rgb, 38, 40, 52},
      chip_fg: {:rgb, 242, 242, 240},
      code_theme: :base16_ocean_dark
    },
    # Cyan turns teal here: the dark themes' cyan has no contrast on a
    # light ground.
    daylight: %{
      ground: {:rgb, 239, 241, 245},
      text: {:rgb, 31, 35, 48},
      subtle: {:rgb, 84, 88, 100},
      muted: {:rgb, 96, 104, 128},
      accent: {:rgb, 192, 24, 159},
      violet: {:rgb, 100, 55, 200},
      cyan: {:rgb, 8, 106, 124},
      chip_bg: {:rgb, 218, 222, 232},
      chip_fg: {:rgb, 31, 35, 48},
      code_theme: :base16_ocean_light
    }
  }

  @names [:dracula, :midnight, :daylight]

  @doc "Theme names in cycling order, default first."
  @spec names() :: [atom()]
  def names, do: @names

  @doc "The default theme's name."
  @spec default() :: atom()
  def default, do: @default

  @doc "The theme struct for `name`. Raises on an unknown name."
  @spec fetch!(atom()) :: t()
  def fetch!(name) when is_map_key(@themes, name),
    do: struct!(__MODULE__, Map.put(@themes[name], :name, name))

  def fetch!(name),
    do: raise(ArgumentError, "unknown theme #{inspect(name)}, expected one of #{inspect(@names)}")

  @doc "The theme after `name` in `names/0`, wrapping around."
  @spec next(atom()) :: atom()
  def next(name) do
    index = Enum.find_index(@names, &(&1 == name)) || -1
    Enum.at(@names, rem(index + 1, length(@names)))
  end

  @doc """
  Parses a theme name from a string (the `--theme` flag). Returns
  `{:ok, name}` or `:error` for anything that isn't a known theme.
  """
  @spec parse(String.t()) :: {:ok, atom()} | :error
  def parse(string) when is_binary(string) do
    case Enum.find(@names, &(Atom.to_string(&1) == string)) do
      nil -> :error
      name -> {:ok, name}
    end
  end

  @doc "Makes `name` the active theme for this process."
  @spec put(atom()) :: :ok
  def put(name) do
    Process.put(@key, fetch!(name))
    :ok
  end

  @doc "The active theme for this process, or the default outside a host."
  @spec current() :: t()
  def current, do: Process.get(@key) || fetch!(@default)

  @doc "A theme colour as a plain `{r, g, b}` tuple, for the 3D scene."
  @spec rgb(rgb()) :: {0..255, 0..255, 0..255}
  def rgb({:rgb, r, g, b}), do: {r, g, b}

  @doc """
  WCAG contrast ratio between two colours, from 1.0 (none) to 21.0.
  Body text wants at least 4.5, large text and chrome at least 3.0.
  """
  @spec contrast(rgb(), rgb()) :: float()
  def contrast(a, b) do
    [hi, lo] = Enum.sort([luminance(a), luminance(b)], :desc)
    (hi + 0.05) / (lo + 0.05)
  end

  defp luminance({:rgb, r, g, b}) do
    [r, g, b]
    |> Enum.map(&channel/1)
    |> then(fn [r, g, b] -> 0.2126 * r + 0.7152 * g + 0.0722 * b end)
  end

  defp channel(value) do
    v = value / 255
    if v <= 0.03928, do: v / 12.92, else: :math.pow((v + 0.055) / 1.055, 2.4)
  end
end
