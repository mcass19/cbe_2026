defmodule Mix.Tasks.Slides.Tui do
  @shortdoc "Launches the SlidesTui deck"

  @moduledoc """
  Starts the SlidesTui deck in the controlling terminal.

      $ mix slides.tui
      $ mix slides.tui --theme daylight
      $ mix slides.tui --talk-length 40

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
      Defaults to `110x30`; above it the slides grow to fill the grid.
    * `--presenter-port PORT` — where the presenter view (speaker notes,
      next slide, timer) is served over SSH on `127.0.0.1`. Defaults to
      `2223`; connect with `ssh -p 2223 localhost`.
    * `--no-presenter` — don't serve the presenter view.
    * `--talk-length MINUTES` — the talk's length, shown next to the
      presenter view's timer.

  Logs go to `log/slides_tui.log` rather than the terminal the deck
  draws on.
  """

  use Mix.Task

  # The smallest grid the slides lay out in: the bridge's code next to
  # its bullets is the widest thing, the longest bullet list the tallest.
  # The font size picks the grid, so this is the biggest font that fits.
  @min_size {110, 30}
  @presenter_port 2223
  @log_file "log/slides_tui.log"

  @impl true
  def run(args) do
    {opts, _rest} =
      OptionParser.parse!(args,
        strict: [
          pattern: :string,
          theme: :string,
          min_size: :string,
          presenter: :boolean,
          presenter_port: :integer,
          talk_length: :integer
        ]
      )

    {presenter?, opts} = Keyword.pop(opts, :presenter, true)
    {talk_length, opts} = Keyword.pop(opts, :talk_length)

    opts =
      opts
      |> Keyword.update(:theme, SlidesTui.Theme.default(), &parse_theme!/1)
      |> Keyword.update(:min_size, @min_size, &parse_size!/1)
      |> Keyword.put(:talk_minutes, talk_length)
      |> Keyword.put_new(:presenter_port, @presenter_port)

    opts = if presenter?, do: opts, else: Keyword.delete(opts, :presenter_port)

    # after app.start, which loads the logger config and would put the
    # console handler back
    Mix.Task.run("app.start")
    log_to_file()

    SlidesTui.run(opts)
  end

  # The deck owns the terminal, so anything the console logger prints
  # lands on a slide (OTP's ssh logs a line per presenter connection).
  # Logs go to a file instead.
  defp log_to_file do
    File.mkdir_p!(Path.dirname(@log_file))
    _ = :logger.remove_handler(:default)

    :ok =
      :logger.add_handler(:slides_tui_file, :logger_std_h, %{
        level: :info,
        config: %{file: String.to_charlist(@log_file)},
        formatter: Logger.Formatter.new(colors: [enabled: false])
      })
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
      _ -> Mix.raise("--min-size expects COLSxROWS, like 110x30, got #{size}")
    end
  end
end
