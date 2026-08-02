# SlidesTui — the "TUIs everywhere" deck

The slides for the Code BEAM Europe 2026 talk, as a TUI. The deck runner (`SlidesTui.*`) is a small host built on [ex_ratatui](https://hex.pm/packages/ex_ratatui); the talk itself (`TuisEverywhere.Slides.*`) is fourteen slide modules under `lib/slides/`.

Drop slide modules into `lib/slides/`; the host discovers them in filename order, wraps each one with a common chrome (rounded border with optional title, plus a footer with progress and key hints), and routes navigation. Slides can be stateful and interactive — the advanced-widgets slide renders a live spinning cube driven by a subscription that exists only while that slide is on screen.

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

Page Up/Down and Space are what presentation clickers emit, so the deck advances from a clicker with no extra setup.

## The deck

One module per slide, numbered to match the talk outline: title, about me, the ratatui story, architecture (bridge + NIF), transports, the Livebook demo, the cell-session transport, the badge demo, the Phoenix lobby demo, runtimes, advanced widgets, testing & observability, TUIs out there, and thanks. Every slide carries speaker notes (`n`); the demo slides hold the run-of-show for switching away from the deck.

`lib/slides/ui.ex` is a shared helper (headline, bullets, demo interstitial) — it implements no slide behaviour, so discovery skips it. The chrome accent is the same Code BEAM magenta lobby_tui uses, so every TUI in the talk shares one identity.
