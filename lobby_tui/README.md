# lobby_tui

The live demo room for the Code BEAM Europe 2026 talk "TUIs everywhere." A small pixel-art lobby with seats and a chat stage, walkable with the arrow keys, sittable, postable — running as a real terminal UI (`ex_ratatui`) embedded inside a Phoenix LiveView page, on a real local terminal, over SSH, and inside a Livebook cell. One app module, four ways in, everyone in the same room.

## Four entry points, one room

**Browser.** Visit `https://lobby-tui.fly.dev`, pick a nickname and an avatar, and land in the room. Movement is arrow keys or the on-screen D-pad; `s` or Enter sits; the chat box under the room posts to the stage feed once seated.

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

**Livebook.** The room rendered into a notebook cell, via [`kino_ex_ratatui`](https://github.com/mcass19/kino_ex_ratatui)'s xterm.js widget — from a local Livebook whose runtime is *attached to the running Fly node*. Attaching is the whole trick: the room's state (Ash ETS tables, Presence, PubSub) lives in that node's memory, so the notebook cells must execute there to share it, and everything the widget needs (`kino`, `kino_ex_ratatui`) already ships inside the release precisely because attached runtimes cannot `Mix.install`. The ready-made talk notebook is [`notebooks/lobby.livemd`](notebooks/lobby.livemd); the steps below are the full runbook, written to be followed cold.

One-time setup, before the first attach ever works:

```
# 1. Pin the release cookie. Every image build otherwise bakes a fresh random
#    cookie, and the local Livebook needs to know it. The release scripts
#    prefer $RELEASE_COOKIE over the baked file, so a secret pins it across
#    deploys. (Setting it restarts the machine.)
fly secrets set --app lobby-tui RELEASE_COOKIE="$(elixir -e 'IO.puts(Base.url_encode64(:crypto.strong_rand_bytes(40)))')"

# 2. Create a WireGuard peer into the Fly private network and bring it up.
#    Distributed Erlang needs epmd (4369) plus a dynamically chosen port, so a
#    single-port `fly proxy` cannot substitute for the tunnel.
fly wireguard create personal ams lobby-wg lobby-wg.conf
sudo wg-quick up ./lobby-wg.conf

# 3. Deploy a release that includes kino_ex_ratatui in its deps.
fly deploy
```

Every time, on the day:

```
# 1. Tunnel up (no-op if already up).
sudo wg-quick up ./lobby-wg.conf

# 2. Ask the release for its node name and cookie. The node name embeds the
#    image tag, so it CHANGES ON EVERY DEPLOY — re-run this after deploying.
fly ssh console --app lobby-tui -C "/app/bin/lobby_tui rpc 'IO.puts(Node.self()); IO.puts(Node.get_cookie())'"

# 3. Start Livebook with a long node name and IPv6 distribution, so it can
#    dial the node's fdaa:: address.
LIVEBOOK_DISTRIBUTION=name ERL_AFLAGS="-proto_dist inet6_tcp" livebook server notebooks/lobby.livemd
```

Then, in the notebook: runtime settings → **Attached node** → paste the node name and cookie from step 2 → **Connect**, and evaluate the cells. The local Livebook needs to be recent enough to speak to the release's `kino` (0.19), i.e. Livebook 0.19 or newer.

If the attach fails, it is one of three things: the tunnel is down (`sudo wg-quick up ./lobby-wg.conf`), the cookie is wrong (step 2 prints the live one), or the node name is stale because a deploy happened since it was copied (step 2 again). The notebook itself carries a "If something looks wrong" section for everything that can go sideways after the attach.

## How it works

There is exactly one TUI module: `LobbyTui.Theatre`. It implements the `ExRatatui.App` behaviour once — mount, render, handle_event, handle_info — and runs unchanged under four transports:

- **Browser**, via `phoenix_ex_ratatui`'s `PhoenixExRatatui.LiveComponent`, which drives `Theatre` inside a LiveView and streams cell diffs to the client over the socket.
- **Local terminal**, via `ExRatatui.Server` with `transport: :local` (this repository's `LobbyTui.Local`), which drives the identical `Theatre` module against the real OS terminal.
- **SSH**, via `ExRatatui.SSH.Daemon` serving `LobbyTui.Ssh` — a thin shim that turns the connection's SSH username into an attendee and then hands every callback to `Theatre`. The daemon gives each client its own isolated session, server, and state, so a hundred people can `ssh` in at once without sharing anything but the room itself.
- **Livebook**, via `Kino.ExRatatui` serving `LobbyTui.Notebook` — the same shim shape as SSH (nickname in, attendee out, every callback handed to `Theatre`), rendered through xterm.js in a notebook cell on an attached runtime. Free-form nicknames from SSH and the notebook go through one shared funnel, `LobbyTui.Lobby.Join`: sanitize, clamp to 16 characters, suffix on collision.

Pure state transitions live in `LobbyTui.Theatre.State`; rendering lives in `LobbyTui.Theatre.Render`; `Theatre` itself owns the ExRatatui callbacks and the side effects — Ash actions for joining, sitting, and posting, and once connected, Phoenix Presence and PubSub for seeing everyone else move and speak.

The room state (who is where, who said what) is modeled as Ash resources — `Avatar`, `Attendee`, `Seat`, `Message` — under the `LobbyTui.Lobby` domain, backed by ETS. Nothing here touches a database; the whole room lives in memory for the life of the server process.

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

For the other transports instead of (or alongside) the browser, see "Local terminal", "SSH", and "Livebook" above.

## Tests

```
mix test
```

`mix precommit` runs the same checks used before every commit: compile with warnings as errors, drop unused deps, format, and test.

## Deploying

`fly.toml` targets a single Fly.io machine in `ams` (EU), app name `lobby-tui`. The release is built with `mix phx.gen.release --docker`. Deployment itself is not automated from this repository — see `fly.toml` and `Dockerfile` for the shape of it.

The Livebook entry point needs a pinned release cookie and a WireGuard peer — both are one-time steps, covered in the "Livebook" runbook above.

The SSH entry point needs two things beyond a plain deploy.

**A stable host key.** Without one the daemon generates a throwaway key at every boot, and anyone who reconnects after a redeploy meets SSH's changed-host-key warning. Generate a key once, hand it to Fly as a secret, and delete the local copy:

```
ssh-keygen -t ed25519 -f ssh_host_ed25519_key -N ""
fly secrets set --app lobby-tui SSH_HOST_KEY="$(base64 -w0 ssh_host_ed25519_key)"
rm ssh_host_ed25519_key ssh_host_ed25519_key.pub
```

**A dedicated IPv4 address.** Fly's shared IPv4 only routes ports 80 and 443, so the `[[services]]` block on port 22 is reachable over IPv6 alone until an address is allocated:

```
fly ips allocate-v4
```

It costs about $2/month and can be released afterwards with `fly ips release <address>`. Skipping it leaves the browser room untouched and the SSH room invisible to anyone on an IPv4-only network — which is a good half of conference wifi.
