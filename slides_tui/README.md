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

A terminal only scales text through its font size, so the slides scale the other way round: they fill whatever grid the font leaves. Headlines go big once there's room, bullets wrap, and images, the QR, 3D and canvases grow with their share of the slide. So the font size is the zoom: pick one that reads from the back of the room. The deck needs 110×30 at least; below it a "terminal too small" screen shows both sizes instead of clipping slides. `--min-size COLSxROWS` overrides the minimum.

## Presenter view

`mix slides.tui` also serves a presenter view over SSH on `127.0.0.1:2223`: the current slide's notes, the next slide's title, a talk timer and the clock. With the screen extended, the deck goes on the projector and the presenter view on the laptop:

```bash
mix slides.tui --talk-length 40   # projector
ssh -p 2223 localhost             # laptop
```

The presenter view follows the deck live, and the slide keys work in both windows, so the clicker drives the deck whichever one has focus. The timer starts with the deck; `s` in the presenter view restarts it. With `--talk-length` it turns violet in the last five minutes and magenta once over. `q` there closes only the presenter view. The daemon listens on loopback only, with no password; `--presenter-port` moves it and `--no-presenter` turns it off. Logs go to `log/slides_tui.log`, never onto the slides.

## Controls

| Key | Action |
| --- | ------ |
| `←` / `h` / `Page Up` | prev slide |
| `→` / `l` / `Space` / `Page Down` | next slide |
| `t` | cycle colour theme |
| `q` | quit |

