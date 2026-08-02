defmodule SlidesTui do
  @moduledoc """
  A TUI slide-deck runner built on `ex_ratatui`.

  Drop slide modules into `lib/slides/` and they get discovered, ordered,
  and wrapped in a common chrome (rounded border with optional title,
  footer with progress and key hints, toggleable notes popup). See
  `SlidesTui.Slide` for the slide behaviour.

  ## Running a deck

  The simplest path is the bundled mix task:

      $ mix slides.tui

  It starts the host, blocks until `q` is pressed, then exits cleanly so
  the shell prompt comes back. From IEx the equivalent is:

      iex> SlidesTui.run([])

  Both forms forward extra opts to `SlidesTui.Host` — for example
  `mix slides.tui --pattern "path/to/slides/*.ex"` or
  `SlidesTui.run(pattern: "path/to/slides/*.ex")`.

  To embed the deck in a supervision tree instead, use
  `SlidesTui.start_link/1` directly.
  """

  alias SlidesTui.Host

  @doc """
  Starts a deck and blocks until the host exits.

  Use this from a mix task or an IEx session. Returns `:ok` when the
  deck shuts down (typically because the user pressed `q`).

  All options are forwarded to `SlidesTui.Host.start_link/1`.
  """
  @spec run(keyword()) :: :ok
  def run(opts) do
    {:ok, pid} = Host.start_link(opts)
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end

  defdelegate start_link(opts \\ []), to: Host
  defdelegate child_spec(opts), to: Host
end
