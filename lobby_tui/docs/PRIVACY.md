# Privacy notice — TUIs everywhere lobby

This is the plain-language privacy note for the live demo room used at the Code BEAM Europe 2026 talk "TUIs everywhere." It applies to both entry points: the browser room and the local-terminal room, since both run the same code and store data the same way.

## What is stored

The nickname typed at the join screen.

The avatar picked at the join screen.

Chat messages posted while seated.

That is the entire list. Everything above lives in memory only (an in-process ETS table via Ash), never on disk and never in a database.

## What is not stored

No accounts and no passwords — joining is just picking a nickname and an avatar.

No email addresses or any other contact detail.

No analytics, no trackers, no cookies beyond the session cookie needed to keep a browser tab attached to its attendee row.

No persistent identifiers that survive a disconnect — the attendee row (and the nickname/avatar pairing inside it) is destroyed when the session ends, so nothing links a person back to their earlier visit.

## How long data lives

An attendee disappears from the room when their connection drops, after a 30-second grace period (long enough to survive a phone lock or a page refresh without kicking someone out mid-sentence).

Chat messages persist only in memory for the lifetime of the server process — a restart wipes the whole feed. There is no backup and no export.

## Deleting data

There is no self-service delete button. During the session, a request to remove a posted message can be made to the operator running the room, who can remove it from the moderation console (see "Moderation" below).

After a session ends there is no path to identify which messages belonged to a given attendee, since the row linking them together no longer exists by then. For anything else — a request to confirm no residual copy exists, a question about a specific message seen during the talk, or similar — reach the controller at the address below.

## Moderation

An operator can remove any message from the console during the talk (`Lobby.moderate_delete/2`, run by a person, not automated). This exists to handle abuse in the room, not to monitor ordinary conversation.

## Where this runs

The deployed instance runs in the EU (Fly.io, `ams` region).

## Who is responsible

Controller: Mauricio Cassola.
mauricass19@gmail.com
