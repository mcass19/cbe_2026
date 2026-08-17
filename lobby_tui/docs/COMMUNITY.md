# Contributing an avatar sprite

The lobby ships with a small placeholder set of avatars (`priv/sprites_src/*.png`). This doc is the full path from "here is a sprite" to "it renders in the room" for anyone who wants to add one.

## What the file needs to look like

A 12x12 PNG, RGBA, transparent background.

## Licensing

CC0 (public domain) is preferred. CC-BY is acceptable, provided proper attribution is recorded (see below).

Not acceptable: anything marked non-commercial-only or personal-use-only, or any license that would not let this repository (and its forks, and the conference recording built from it) be distributed freely.

## Naming

The filename, minus the `.png` extension, becomes the avatar's name shown in the join screen and above the avatar in the room. `crimson.png` becomes the avatar named "crimson". Pick a name accordingly — lowercase, short, no spaces works best for the join-screen layout.

## Steps

1. Prepare the 12x12 transparent PNG as described above.
2. Drop the file into `priv/sprites_src/` using the filename as the desired avatar name (e.g. `priv/sprites_src/comet.png`).
3. Add a row to the table in `docs/ATTRIBUTION.md` recording the file, author, source, and license — this is required even for CC0 originals authored specifically for this repository.
4. Open a PR with both changes.

## What happens after merge

Sprites are loaded once, at server boot, from every PNG found in `priv/sprites_src/`. There is no hot-reload and no admin upload path — a restart is what picks up a newly merged sprite.
