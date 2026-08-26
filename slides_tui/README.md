# SlidesTui — the "TUIs everywhere" deck

The slides for the Code BEAM Europe 2026 talk, as a TUI. The deck runner (`SlidesTui.*`) is a small host built on [ex_ratatui](https://hex.pm/packages/ex_ratatui); the talk itself (`TuisEverywhere.Slides.*`) are slide modules under `lib/slides/`.

Drop slide modules into `lib/slides/`; the host discovers them in filename order, wraps each one with a common chrome (rounded border with optional title, plus a footer with progress and key hints), and routes navigation. Slides can be stateful and interactive.

## Running it

The bundled mix task launches the deck and returns control to the shell when we press `q`:

```bash
mix deps.get
mix slides.tui
```

From IEx, the equivalent one-liner is:

```elixir
iex> SlidesTui.run([])
```

Both forms block until the host exits, so the controlling shell gets its prompt back cleanly — no `Process.sleep(:infinity)` or `Ctrl+C` dance required.

To point at a different deck, pass `--pattern`:

```bash
mix slides.tui --pattern "path/to/slides/*.ex"
```

Or in code: `SlidesTui.run(pattern: "path/to/slides/*.ex")`.

## Controls

| Key | Action |
| --- | ------ |
| `←` / `h` / `Page Up` | prev slide |
| `→` / `l` / `Space` / `Page Down` | next slide |
| `n` | toggle speaker-notes popup |
| `q` | quit |

