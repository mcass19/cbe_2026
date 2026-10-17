# Code BEAM Europe 2026 - TUIs everywhere

- Slides in `slides_tui`
- Lobby in `lobby_tui`

## Ecosystem shown in the talk

- [ex_ratatui](https://github.com/mcass19/ex_ratatui) — the library
- [kino_ex_ratatui](https://github.com/mcass19/kino_ex_ratatui) — TUIs in Livebook cells
- [phoenix_ex_ratatui](https://github.com/mcass19/phoenix_ex_ratatui) — TUIs in LiveView pages
- [raster_ex_ratatui](https://github.com/mcass19/raster_ex_ratatui) — TUIs on pixel displays (the badge, a Raspberry Pi framebuffer)

## Talk link

https://codebeameurope.com/talks/tuis-everywhere

<details>
<summary>Abstract (as submitted)</summary>

> What if terminal UIs were a first-class option on the BEAM, with the same OTP supervision, observability, and remote-attach story you already trust?
>
> ExRatatui brings Rust’s ratatui to Elixir via precompiled Rustler NIFs with ~20 widgets, a constraint-based layout engine, OTP-supervised apps with LiveView-style callbacks (or an Elm-flavoured reducer runtime), and transport-agnostic apps that run identically over a local terminal, SSH, or Erlang distribution.
>
> The talk aims to include a live demo — a small web game the audience can play from their phones in the room — and walks through the use cases that emerged once TUIs became cheap to build on the BEAM: personal CLI tools, rapid prototyping inside Livebook (kino_ex_ratatui), Phoenix LiveView panels rendering the same TUI in a browser, and embedded e-ink screens via cell-buffer transport.
>
> You’ll leave knowing when a TUI is the right answer, what’s already possible today, and how OTP makes TUIs more interesting than they are in most ecosystems.
>
> **Key takeaways**
>
> - Full-featured TUIs are a real option on Elixir today, with no Rust toolchain required.
> - The same TUI module runs locally, over SSH, in a Livebook cell, on an e-ink panel, or inside a LiveView. You pick the transport.
> - OTP supervision + remote attach turns ad-hoc CLI tools into long-lived, observable, multi-user surfaces.
>
> **Target audience**
>
> Elixir developers curious about TUIs, operators who want observability surfaces beyond logs, Nerves/embedded folks looking for richer interfaces on small screens, and anyone who’d reach for a TUI in another language and didn’t realize the BEAM could match it.

</details>

## Video

Will be posted here once released.

## License

MIT — see [LICENSE](https://github.com/mcass19/cbe_2026/blob/main/LICENSE) for details.
