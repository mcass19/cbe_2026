defmodule Mix.Tasks.Slides.Tui do
  @shortdoc "Launches the SlidesTui deck"

  @moduledoc """
  Starts the SlidesTui deck in the controlling terminal.

      $ mix slides.tui

  Discovers slides from `lib/slides/*.ex` by default, mounts the first
  one, and renders inside the SlidesTui chrome. Press `q` to quit; the
  task returns control to the shell once the host has shut down.

  ## Options

    * `--pattern PATTERN` — glob forwarded to `SlidesTui.Deck.discover/1`.
      Defaults to `"lib/slides/*.ex"`.
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [pattern: :string])

    Mix.Task.run("app.start")

    SlidesTui.run(opts)
  end
end
