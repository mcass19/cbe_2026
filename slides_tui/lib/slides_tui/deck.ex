defmodule SlidesTui.Deck do
  @moduledoc """
  Slide discovery and ordering.

  Globs `lib/slides/*.ex` (or `opts[:pattern]`), sorts the matches
  lexicographically by filename, parses each file's first `defmodule`
  line to derive the module atom, and keeps only those that implement
  `SlidesTui.Slide`.

  Non-slide modules sitting next to slides (helpers, support files)
  are silently skipped — they can live in `lib/slides/` without
  breaking discovery.

  Filenames are zero-padded by convention (`01_intro.ex`,
  `02_overview.ex`, …) since lexicographic sort places `10_*.ex`
  before `2_*.ex`.
  """

  @default_pattern "lib/slides/*.ex"
  @defmodule_regex ~r/^\s*defmodule\s+([A-Z][\w.]*)\s+do/m

  @doc """
  Returns the ordered list of slide modules.

  ## Options

    * `:pattern` — glob pattern relative to the application root.
      Defaults to `"lib/slides/*.ex"`. Tests point this at fixture
      directories.

  Returns `[]` when the pattern matches nothing; the host renders a
  placeholder slide in that case.
  """
  @spec discover(keyword()) :: [module()]
  def discover(opts \\ []) do
    pattern = Keyword.get(opts, :pattern, @default_pattern)

    pattern
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&module_from_file/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&slide?/1)
  end

  defp module_from_file(path) do
    case Regex.run(@defmodule_regex, File.read!(path)) do
      [_, name] ->
        module = Module.concat([name])
        if Code.ensure_loaded?(module), do: module, else: nil

      _ ->
        nil
    end
  end

  defp slide?(module) do
    behaviours =
      module.__info__(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    SlidesTui.Slide in behaviours
  end
end
