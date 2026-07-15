# Contributing an avatar sprite

The lobby ships with a small placeholder set of avatars (`priv/sprites_src/*.png`). This doc is the full path from "here is a sprite" to "it renders in the room" for anyone who wants to add one.

## What the file needs to look like

A 12x12 PNG, RGBA, transparent background.

12x12 matches the built-in placeholder set exactly — every existing sprite is that size, and the room's rendering budget assumes it. A different size still decodes and converts, but will look inconsistent next to the rest of the cast, so 12x12 is the expectation, not just a suggestion.

Transparent background: any pixel below alpha 128 counts as transparent and is skipped; alpha 128 or above counts as opaque and is drawn. There is no partial-opacity blending — each pixel resolves to fully in or fully out at that threshold.

The room renders sprites in half-block cells: each terminal cell covers two source pixel rows, drawn as the top-half block character with the top pixel's color as foreground and the bottom pixel's color as background. A cell with only the top pixel opaque draws just the top half against the world behind it; only the bottom opaque draws just the bottom half; neither opaque draws nothing. This means a 12x12 sprite becomes 12 columns by 6 rows of cells, and any single-pixel-wide detail should be thought of as "one row of a two-row pair," not a full cell on its own.

## Licensing

CC0 (public domain) is preferred. CC-BY is acceptable, provided proper attribution is recorded (see below).

Not acceptable: anything marked non-commercial-only or personal-use-only, or any license that would not let this repository (and its forks, and the conference recording built from it) be distributed freely.

If unsure whether a source's license clears this bar, ask in the PR rather than guessing.

## Naming

The filename, minus the `.png` extension, becomes the avatar's name shown in the join screen and above the avatar in the room. `crimson.png` becomes the avatar named "crimson". Pick a name accordingly — lowercase, short, no spaces works best for the join-screen layout.

## Steps

1. Prepare the 12x12 transparent PNG as described above.
2. Drop the file into `priv/sprites_src/` using the filename as the desired avatar name (e.g. `priv/sprites_src/comet.png`).
3. Add a row to the table in `docs/ATTRIBUTION.md` recording the file, author, source, and license — this is required even for CC0 originals authored specifically for this repository.
4. Open a PR with both changes.

## What happens after merge

Sprites are loaded once, at server boot, from every PNG found in `priv/sprites_src/`. There is no hot-reload and no admin upload path — a restart is what picks up a newly merged sprite.

A corrupt or unreadable file does not stop the boot or take down the other avatars: it is skipped, a warning is logged naming the file, and the room continues seeding the rest. If a sprite silently fails to show up after a restart, that warning in the server log is the first place to look.

There is always a built-in `unknown` avatar (a plain gray placeholder) seeded regardless of what is in `priv/sprites_src/`, so the room can never end up with zero avatars to offer even if every custom file fails to decode.
