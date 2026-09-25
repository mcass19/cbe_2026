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

## Themes

The deck paints every colour itself, background included, so the terminal's own theme never shows through. Three themes ship: `dracula` (the default), `midnight` (near-black, for projectors that wash out dark greys) and `daylight` (off-white, for brightly lit rooms). Start on one with `--theme`, cycle with `t`:

```bash
mix slides.tui --theme daylight
```

## Terminal size

The widest slides need a 152×39 grid. Below it the deck shows a "terminal too small" screen with both sizes instead of clipping slides, so the font can be tuned until the deck appears. `--min-size COLSxROWS` overrides the minimum.

## Controls

| Key | Action |
| --- | ------ |
| `←` / `h` / `Page Up` | prev slide |
| `→` / `l` / `Space` / `Page Down` | next slide |
| `n` | toggle speaker-notes popup |
| `t` | cycle colour theme |
| `q` | quit |

