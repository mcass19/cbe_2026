# lobby_tui

The live demo room for the Code BEAM Europe 2026 talk "TUIs everywhere." A small pixel-art lobby with seats and a chat stage, walkable with the arrow keys, sittable, postable — running as a real terminal UI (`ex_ratatui`) embedded inside a Phoenix LiveView page, and also runnable as a real terminal UI on a real terminal, no browser involved.

## Two entry points, one room

**Browser.** Visit `https://<talk-demo-url>/` (placeholder — filled in closer to the talk), pick a nickname and an avatar, and land in the room. Movement is arrow keys or the on-screen D-pad; `s` or Enter sits; the chat box under the room posts to the stage feed once seated.

**Local terminal.** From a real terminal (not backgrounded, not piped — the TUI needs a TTY):

```
cd lobby_tui
iex -S mix
```

then, at the `iex>` prompt:

```elixir
LobbyTui.Local.run("speaker")
```

This joins the same room as any browser attendee, using the same PubSub/Presence backbone, so people in the browser and people on a terminal see each other move in real time. Press `q` to leave. `LobbyTui.Local.run/2` blocks until the terminal session ends (`q`, window closed, process killed), then leaves the room immediately rather than waiting out the disconnect grace period.

## How it works

There is exactly one TUI module: `LobbyTui.Theatre`. It implements the `ExRatatui.App` behaviour once — mount, render, handle_event, handle_info — and runs unchanged under three transports:

- **Browser**, via `phoenix_ex_ratatui`'s `PhoenixExRatatui.LiveComponent`, which drives `Theatre` inside a LiveView and streams cell diffs to the client over the socket.
- **Local terminal**, via `ExRatatui.Server` with `transport: :local` (this repository's `LobbyTui.Local`), which drives the identical `Theatre` module against the real OS terminal.
- **SSH** (pass two, not in this repository yet) — a per-connection `Theatre` behind an SSH daemon, so `ssh lobby.example.com` becomes a third way into the same room.

Pure state transitions live in `LobbyTui.Theatre.State`; rendering lives in `LobbyTui.Theatre.Render`; `Theatre` itself owns the ExRatatui callbacks and the side effects — Ash actions for joining, sitting, and posting, and once connected, Phoenix Presence and PubSub for seeing everyone else move and speak.

The room state (who is where, who said what) is modeled as Ash resources — `Avatar`, `Attendee`, `Seat`, `Message` — under the `LobbyTui.Lobby` domain, backed by ETS. Nothing here touches a database; the whole room lives in memory for the life of the server process.

## Scaffolding story

This app started from Igniter, not `phx.new` directly:

```
cd cbe_2026
mix igniter.new lobby_tui --with phx.new --with-args="--no-ecto" --install ash,ash_phoenix --no-git --yes
```

`phoenix_ex_ratatui` was added to `mix.exs` by hand and wired into `assets/js/app.js` as a LiveSocket hook.

The Ash domain and resources were generated with `ash.gen.*`, then hand-edited for actions, policies, and calculations:

```
mix ash.gen.domain LobbyTui.Lobby --yes

mix ash.gen.resource LobbyTui.Lobby.Avatar \
  --uuid-primary-key id \
  --attribute name:string:required:public,license:string,attribution:string \
  --extend ets --default-actions read --yes

mix ash.gen.resource LobbyTui.Lobby.Attendee \
  --uuid-primary-key id \
  --attribute nickname:string:required:public \
  --relationship belongs_to:avatar:LobbyTui.Lobby.Avatar:required \
  --extend ets --default-actions read --yes

mix ash.gen.resource LobbyTui.Lobby.Seat \
  --uuid-primary-key id \
  --attribute row:integer:required,col:integer:required,x:integer:required,y:integer:required \
  --extend ets --default-actions read --yes

mix ash.gen.resource LobbyTui.Lobby.Message \
  --uuid-primary-key id \
  --attribute body:string:required:public \
  --extend ets --yes
```

Everything after generation — the `claim`/`release`/`join`/`leave`/`post`/`moderate` actions, the seat-claim atomicity, the rate limit and seat-gating policies, sprite loading, the world grid, Presence wiring, and the Theatre TUI itself — is hand-written on top of that scaffold.

## Data honesty

The room's own join screen and in-room footer carry this exact notice, verbatim, since it is the truth attendees see live:

> Everything here lives in memory (ETS via Ash). You disappear when you disconnect. Messages are wiped when the server restarts. Please don't post personal information.

The full privacy note, including what data is kept, for how long, and who to contact, is in [`docs/PRIVACY.md`](docs/PRIVACY.md).

## Contributing an avatar

Sprites are 12x12 transparent PNGs dropped into `priv/sprites_src/`. The full contribution path — sizing, licensing, attribution, and what happens after a PR merges — is in [`docs/COMMUNITY.md`](docs/COMMUNITY.md).

## Running it

```
mix setup
mix phx.server
```

Then visit `localhost:4000`.

For the local-terminal transport instead of (or alongside) the browser, see "Local terminal" above.

## Tests

```
mix test
```

`mix precommit` runs the same checks used before every commit: compile with warnings as errors, drop unused deps, format, and test.

## Deploying

`fly.toml` targets a single Fly.io machine in `ams` (EU), app name `lobby-tui`. The release is built with `mix phx.gen.release --docker`. Deployment itself is not automated from this repository — see `fly.toml` and `Dockerfile` for the shape of it.
