# TODO

## Completed
- ✅ Session character name display
- ✅ Flight path tracking (start/land)
- ✅ Quest turn-in name detection
- ✅ Combat-session aggregation
- ✅ Loot merge window with quest flush

## Pending
- Money loot logging
    - Goal: Log copper/silver/gold looted from mobs with readable formatting.
    - Success: Killing a mob that drops coin adds a `Looted: Xg Ys Zc` entry that matches chat text.
- Item equip logging (upgrades)
    - Goal: Detect when the player equips an item and log the change.
    - Success: Equipping an item logs `Equipped: <item>` with slot info and old item if replaced.
- AFK status logging
    - Goal: Log when the player goes AFK and when they return.
    - Success: `/afk` or inactivity logs `AFK` entry; moving/typing logs `Back` entry.
- Testing checklist
    - Goal: Verify core MVP flows in-game.
    - Success: Sessions, quest accept/turn-in, kills/XP, loot, death, `/journal` UI all log correctly.
- Export session as text
    - Goal: Export selected session entries to plain text.
    - Success: Button copies full session text to clipboard or saves to a file.
- Settings page
    - Goal: Provide a settings UI for common preferences.
    - Success: Settings can change logging options and persist across reloads.
- Merge sessions
    - Goal: Combine two sessions into one.
    - Success: Merged session preserves entry order and removes the source session.
- Manual session controls
    - Goal: Allow manual start/stop (and pause) of sessions.
    - Success: Controls create/close sessions deterministically; auto logging respects pause.
- Search/filter
    - Goal: Filter entries by text or type.
    - Success: Typing filters the visible list without modifying stored data.
- Session rename/notes
    - Goal: Add a label/notes for a session.
    - Success: Label shows in dropdown and persists in SavedVariables.
- Session retention controls
    - Goal: Configure auto-prune by age/count.
    - Success: Old sessions are removed per settings without errors.
- Session split
    - Goal: Split a session at a timestamp into two.
    - Success: Entries before/after split are separated and timestamps preserved.
- Track reputation gain
    - Goal: Track reputation gain from quests and other sources.
    - Success: Reputation gain is logged as a separate entry and if the amount results in a new reputation tier, log the new tier.