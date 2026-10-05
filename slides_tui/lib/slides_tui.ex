defmodule SlidesTui do
  @moduledoc """
  A TUI slide-deck runner built on `ex_ratatui`.

  Drop slide modules into `lib/slides/` and they get discovered, ordered,
  and wrapped in a common chrome (rounded border with optional title,
  footer with progress and key hints), with speaker notes in a
  presenter view served over SSH (`SlidesTui.Presenter`). See
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

  alias SlidesTui.{Host, Presenter}

  @doc """
  Starts a deck and blocks until the host exits.

  Use this from a mix task or an IEx session. Returns `:ok` when the
  deck shuts down (typically because the user pressed `q`).

  With `:presenter_port`, the presenter view (`SlidesTui.Presenter`) is
  served over SSH on that port first, so a busy port fails before the
  deck takes over the terminal. The daemon stops with the deck. Every
  other option is forwarded to `SlidesTui.Host.start_link/1`.
  """
  @spec run(keyword()) :: :ok
  def run(opts) do
    {presenter_port, opts} = Keyword.pop(opts, :presenter_port)
    daemon = start_presenter(presenter_port)

    {:ok, pid} = Host.start_link(opts)
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> stop_presenter(daemon)
    end
  end

  defp start_presenter(nil), do: nil

  defp start_presenter(port) do
    {:ok, daemon} = Presenter.start_daemon(port)
    daemon
  end

  defp stop_presenter(nil), do: :ok
  defp stop_presenter(daemon), do: GenServer.stop(daemon)

  defdelegate start_link(opts \\ []), to: Host
  defdelegate child_spec(opts), to: Host
end
