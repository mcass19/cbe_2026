# lobby_tui

The live demo room for the Code BEAM Europe 2026 talk "TUIs everywhere." A small pixel-art lobby with seats and a chat stage, walkable with the arrow keys, sittable, postable — running as a real terminal UI (`ex_ratatui`) embedded inside a Phoenix LiveView page, on a real local terminal, over SSH, and inside a Livebook cell. One app module, four ways in, everyone on the same node in the same room.

The deployed room at `lobby-tui.fly.dev` was up for the talk and may be offline now; `mix phx.server` (with `LOBBY_SSH=1` for SSH) runs the same room locally, see "Running it" below.

## Four entry points, one room

**Browser.** Visit `https://lobby-tui.fly.dev`, pick a nickname and an avatar, and land in the room. Movement is arrow keys or the on-screen D-pad; `s` or Enter sits; the chat box under the room posts to the stage feed once seated.

**SSH.** No clone, no install — any terminal with an SSH client:

```
ssh alice@lobby-tui.fly.dev
```

The username is the nickname: `ssh alice@…` walks in as "alice", and a name already in the room gets a suffix ("alice-2"). The avatar is picked at random. Press `q` or simply close the connection to leave; either way the seat frees immediately. The daemon asks for no password — the room is public, the username is a display name and nothing more.

Locally, the same endpoint is opt-in:

```
LOBBY_SSH=1 mix phx.server
# then, from another terminal
ssh alice@localhost -p 2222
```

**Livebook.** The room rendered into a notebook cell, via [`kino_ex_ratatui`](https://github.com/mcass19/kino_ex_ratatui)'s xterm.js widget — from a local Livebook whose runtime is *attached to the running Fly node*. Attaching is the whole trick: the room's state (Ash ETS tables, Presence, PubSub) lives in that node's memory, so the notebook cells must execute there to share it, and everything the widget needs (`kino`, `kino_ex_ratatui`) already ships inside the release precisely because attached runtimes cannot `Mix.install`. The ready-made talk notebook is [`notebooks/lobby.livemd`](notebooks/lobby.livemd).

The steps below are the full runbook, written to be followed cold.

```
# 1. Tunnel up (no-op if already up). AppArmor keeps wg-quick from reading
#    configs outside /etc/wireguard, so install the config there once.
sudo install -m 600 -o root -g root lobby-wg.conf /etc/wireguard/
sudo wg-quick up lobby-wg

# 2. Ask the release for its node name and cookie. The node name embeds the
#    image tag, so it CHANGES ON EVERY DEPLOY — re-run this after deploying.
fly ssh console --app lobby-tui -C "/app/bin/lobby_tui rpc 'IO.puts(Node.self()); IO.puts(Node.get_cookie())'"

# 3. Start Livebook with a long node name and IPv6 distribution, so it can
#    dial the node's fdaa:: address.
LIVEBOOK_DISTRIBUTION=name ERL_AFLAGS="-proto_dist inet6_tcp" livebook server notebooks/lobby.livemd
```

Then, in the notebook: runtime settings → **Attached node** → paste the node name and cookie from step 2 → **Connect**, and evaluate the cells. The local Livebook needs to be recent enough to speak to the release's `kino` (0.19), i.e. Livebook 0.19 or newer.

**Local terminal.** From a real terminal (not backgrounded, not piped — the TUI needs a TTY):

```
cd lobby_tui
iex -S mix
```

then, at the `iex>` prompt:

```elixir
LobbyTui.Local.run("speaker")
```

The room lives in the node's own memory, so this one is the local node's: a browser on the same `mix phx.server` walks into it, `lobby-tui.fly.dev` does not. SSH is the way to put a real terminal in the deployed room.

## How it works

There is exactly one TUI module: `LobbyTui.Theatre`. It implements the `ExRatatui.App` behaviour once — mount, render, handle_event, handle_info — and runs unchanged under the four transports.

Pure state transitions live in `LobbyTui.Theatre.State`; rendering lives in `LobbyTui.Theatre.Render`; `Theatre` itself owns the ExRatatui callbacks and the side effects — Ash actions for joining, sitting, and posting, and once connected, Phoenix Presence and PubSub for seeing everyone else move and speak.

The room state (who is where, who said what) is modeled as Ash resources — `Avatar`, `Attendee`, `Seat`, `Message` — under the `LobbyTui.Lobby` domain, backed by ETS. Nothing here touches a database; the whole room lives in memory for the life of the server process.

## Data honesty

The room's own join screen and in-room footer carry this exact notice, verbatim, since it is the truth attendees see live:

> Everything here lives in memory (ETS via Ash). Attendees disappear on disconnect. Messages are wiped when the server restarts. Please don't post personal information.

The full privacy note, including what data is kept, for how long, and who to contact, is in [`docs/PRIVACY.md`](docs/PRIVACY.md).

## Contributing an avatar

Sprites are 12x12 transparent PNGs dropped into `priv/sprites_src/`. See [`docs/COMMUNITY.md`](docs/COMMUNITY.md).

## Running it

```
mix setup
mix phx.server
```

Then visit `localhost:4000`.

For the other transports instead of (or alongside) the browser, see "Local terminal", "SSH", and "Livebook" above.

## Tests

```
mix test
```

`mix precommit` runs the same checks used before every commit: compile with warnings as errors, drop unused deps, format, and test.

