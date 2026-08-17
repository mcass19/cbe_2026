# Privacy notice

This is the plain-language privacy note for the live demo room used at the Code BEAM Europe 2026 talk "TUIs everywhere." It applies to all three entry points — the browser, a local terminal, and SSH — since they run the same code and store data the same way.

## What is stored

The nickname typed at the join screen. Over SSH there is no join screen: the nickname is the username offered by the SSH client (`ssh alice@…` joins as "alice"), which is stored exactly like any other nickname.

The avatar picked at the join screen, or a random one over SSH.

Chat messages posted while seated.

That is the entire list. Everything above lives in memory only (an in-process ETS table via Ash), never on disk and never in a database.

## What is not stored

No accounts and no passwords — joining is just picking a nickname and an avatar, and the SSH endpoint asks for no credentials either. No SSH public keys are recorded.

No email addresses or any other contact detail.

No analytics, no trackers, no cookies beyond the session cookie needed to keep a browser tab attached to its attendee row.

No persistent identifiers that survive a disconnect — the attendee row (and the nickname/avatar pairing inside it) is destroyed when the session ends, so nothing links a person back to their earlier visit.

## How long data lives

An attendee disappears from the room when their connection drops, after a 30-second grace period (long enough to survive a phone lock or a page refresh without kicking someone out mid-sentence). An SSH disconnect is unambiguous — there is no tab to refresh — so those attendees are removed immediately, with no grace period.

Chat messages persist only in memory for the lifetime of the server process — a restart wipes the whole feed. There is no backup and no export.

## Moderation

An operator can remove any message from the console during the talk (`Lobby.moderate_delete/2`, run by a person, not automated). This exists to handle abuse in the room, not to monitor ordinary conversation.

## Where this runs

The deployed instance runs in the EU (Fly.io, `ams` region).

## Who is responsible

Mauricio Cassola.
mauricass19@gmail.com
