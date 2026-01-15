# Journaling Addon Plan

## Scope and defaults

- MVP: session log only (quests, kills/XP, loot/skin results, travel, deaths) with automatic session boundary on login/logout.
- Data retention default: keep all sessions.
- UI: minimal scrollable frame with session selector, no todo list yet.

## Data model

- SavedVariables table `JournalDB` with:
- `sessions`: array of sessions, each `{ startTime, endTime, entries[] }`.
- `entries[]`: `{ ts, type, text, meta }` where `text` is the rendered human string; `meta` holds optional structured data for future filtering.
- Session lifecycle:
- On `PLAYER_LOGIN` create new session entry.
- On `PLAYER_LOGOUT` finalize `endTime` and save.

## Event capture (lightweight)

- Quests: `QUEST_TURNED_IN`, `QUEST_ACCEPTED` -> log quest name + id.
- Kills: `COMBAT_LOG_EVENT_UNFILTERED` filter to `UNIT_DIED` and NPCs; keep a rolling 60s aggregation by mob name.
- XP: `PLAYER_XP_UPDATE` diff current XP vs last seen to avoid double counting; log total XP gained per 60s window.
- Loot/skinning: `CHAT_MSG_LOOT` parse for crafting drops (light leather, scraps); store raw chat line in `meta` for later locale-safe parsing; aggregate per 60s window before logging.
- Travel: prefer `ZONE_CHANGED_NEW_AREA` + last zone snapshot; optionally annotate “Flew to …” if a taxi was used (track `TAXIMAP_OPENED` and `UNIT_SPELLCAST_SUCCEEDED` for taxi spells).
- Deaths: `PLAYER_DEAD` + rolling buffer of recent damage events (e.g., last 5-10 seconds) to summarize “died to … (lvl X)”.

## UI

- Slash command `/journal` toggles frame.
- Frame shows:
- Session dropdown (current + previous) at top.
- Scrollable list of entries with timestamps and text.
- Keep UI in one file, no external libs.
- Note: API target is WoW 2.5.5 (TBC anniversary), avoid retail-only APIs.

## Files

- Addon folder (e.g., `[Workspace]/JournalingAddon/`):
- `[Workspace]/JournalingAddon/JournalingAddon.toc` with SavedVariables.
- `[Workspace]/JournalingAddon/Journal.lua` for session storage + event handlers.
- `[Workspace]/JournalingAddon/JournalUI.lua` for minimal UI and slash command.

## Testing

- Moved to `todo.md`.