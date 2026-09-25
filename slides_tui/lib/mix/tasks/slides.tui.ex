defmodule Mix.Tasks.Slides.Tui do
  @shortdoc "Launches the SlidesTui deck"

  @moduledoc """
  Starts the SlidesTui deck in the controlling terminal.

      $ mix slides.tui
      $ mix slides.tui --theme daylight

  Discovers slides from `lib/slides/*.ex` by default, mounts the first
  one, and renders inside the SlidesTui chrome. Press `q` to quit; the
  task returns control to the shell once the host has shut down.

  ## Options

    * `--pattern PATTERN` — glob forwarded to `SlidesTui.Deck.discover/1`.
      Defaults to `"lib/slides/*.ex"`.
    * `--theme NAME` — the starting colour theme, one of
      `SlidesTui.Theme.names/0` (`dracula`, `midnight`, `daylight`).
      Press `t` in the deck to cycle.
    * `--min-size COLSxROWS` — the smallest terminal the deck renders
      in; below it a "terminal too small" screen shows the numbers.
      Defaults to `152x39`, what the widest and tallest slides need.
  """

  use Mix.Task

  # The widest slides lay out 150 cells inside the border; the lobby's
  # QR is the tallest at 36 rows plus border and footer.
  @min_size {152, 39}

  @impl true
  def run(args) do
    {opts, _rest} =
      OptionParser.parse!(args, strict: [pattern: :string, theme: :string, min_size: :string])

    opts =
      opts
      |> Keyword.update(:theme, SlidesTui.Theme.default(), &parse_theme!/1)
      |> Keyword.update(:min_size, @min_size, &parse_size!/1)

    Mix.Task.run("app.start")

    SlidesTui.run(opts)
  end

  defp parse_theme!(name) do
    case SlidesTui.Theme.parse(name) do
      {:ok, theme} ->
        theme

      :error ->
        Mix.raise(
          "unknown --theme #{name}, expected one of #{Enum.join(SlidesTui.Theme.names(), ", ")}"
        )
    end
  end

  defp parse_size!(size) do
    with [cols, rows] <- String.split(size, "x"),
         {cols, ""} <- Integer.parse(cols),
         {rows, ""} <- Integer.parse(rows) do
      {cols, rows}
    else
      _ -> Mix.raise("--min-size expects COLSxROWS, like 152x39, got #{size}")
    end
  end
end
