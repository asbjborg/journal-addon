# TODO

## Completed

Completed tasks are tracked in [changes.md](changes.md).

## Pending

- Money loot logging
    - Goal: Log copper/silver/gold looted from mobs with readable formatting.
    - Success: Killing a mob that drops coin adds a `Looted: Xg Ys Zc` entry that matches chat text.
- Money income
    - Goal: Track money income from quests and other sources.
    - Success: Money income is logged as a separate entry.
- Item equip logging (upgrades)
    - Goal: Detect when the player equips an item and log the change.
    - Success: Equipping an item logs `Equipped: <item>` with slot info and old item if replaced.
- AFK status logging
    - Goal: Log when the player goes AFK and when they return.
    - Success: `/afk` or inactivity logs `AFK` entry; moving/typing logs `Back` entry.
- Testing checklist
    - Goal: Verify core MVP flows in-game.
    - Success: Sessions, quest accept/turn-in, kills/XP, loot, death, `/journal` UI all log correctly.
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
- When setting a new Hearthstone location, log the new location in the journal.
    - Goal: Ensure the new Hearthstone location is logged in the journal.
    - Success: Hearthstone location is logged in the journal: "Set Hearthstone to [location]"
    - Notes:
        - Look for "<Inn> is now your home" in the system chat messages.
- Crafting item logging
    - Goal: Log when items are crafted with item name and quantity.
    - Success: Crafting an item logs "Crafted: [item] x[count]" entry in the journal.
    - Notes:
        - Track crafting via `CHAT_MSG_SKILL` or `UNIT_SPELLCAST_SUCCEEDED` for crafting spells.
        - Parse chat messages like "You create [item]." or similar.
- Mail received logging
    - Goal: Log when mail is received with sender name and items/content.
    - Success: Receiving mail logs "Received mail from [sender]: [items/content]" entry.
    - Notes:
        - Use `MAIL_SHOW` or `MAIL_INBOX_UPDATE` events.
        - Parse mail items from `GetInboxItem()` or chat messages.
- Mail sent logging
    - Goal: Log when mail is sent with recipient name and items/content.
    - Success: Sending mail logs "Sent mail to [recipient]: [items/content]" entry.
    - Notes:
        - Use `MAIL_SEND_SUCCESS` event or hook `SendMail()` function.
        - Capture items and recipient before sending.
- Track when consuming food or drink
    - Goal: Log when food or drink is consumed with item name and quantity.
    - Success: Consuming food or drink logs "Consumed: [item] x[count]" entry in the journal.
    - Notes:
        - Track consumption via `UNIT_SPELLCAST_SUCCEEDED` for food/drink spells.
        - Parse buffs like "Well fed" if the food or drink provided a buff and append to the entry.