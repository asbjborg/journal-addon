# Changelog

## [0.6.6] - 2026-01-17

### Fixed

- **Flight start verification and deduplication** (#39)
    - Verifies flight actually started after 3 seconds - removes entry if player is not on taxi
    - Deduplicates identical "Started flying" entries within 30 seconds
    - Prevents duplicate flight entries when flight fails (e.g., due to shapeshift) or when player retries quickly
    - Handles both scenarios: flight fails completely, or player shapeshifts out and retries successfully

## [0.6.5] - 2026-01-17

### Changed

- **Loot aggregation stores raw duration** (#36)
    - Changed from storing pre-formatted `durationText` to raw `duration` (in seconds)
    - Renderer now formats duration from raw value (e.g., "3m", "180s")
    - Allows for future flexibility in duration formatting (e.g., "over a while", "for some time")

- **Quest turn-in appears before related events** (#38)
    - Quest turn-in entry now appears before level up, XP gain, and reputation changes it triggers
    - Reorders events so "Turned in" appears first, followed by related reward events
    - Maintains correct chronological order for storytelling purposes

### Fixed

- **Quest rewards excluded from loot aggregation** (#37)
    - Quest reward loot is now logged immediately, bypassing loot aggregation window
    - Quest rewards appear right after "Turned in" entry (within 10 seconds)
    - Only non-quest loot (gathering, combat drops) goes through aggregation window
    - Prevents quest rewards from being held back and appearing later with unrelated loot

## [0.6.4] - 2026-01-17

### Added

- **Loot aggregation for repeated gathering** (#33)
    - Aggregates repeated loot messages (especially from gathering like clams/meat) into a single summary line
    - Uses a 3-minute aggregation window that triggers on loot/gathering loops (even outside combat)
    - Format: `Looted: [Item] x[N], [Item] x[M] (over [time])`
    - Improves readability for storytelling purposes by reducing spam from repeated gathering activities
    - Works independently from combat aggregation window

## [0.6.3] - 2026-01-17

### Added

- **Subzone ping-pong detection** (#32)
    - Detects when the same two subzones flip back and forth within 5 seconds
    - Logs first "Entered X from Y" transition normally
    - Subsequent ping-pong transitions are suppressed and replaced with a single "Border dancing near [Zone Name]" message
    - Reduces log spam at zone boundaries (e.g., Ethel Rethor ↔ Sar'theris Strand)
    - Improves readability for storytelling purposes

## [0.6.2] - 2026-01-17

### Added

- **X,Y coordinates on zone/subzone changes** (#31)
    - Captures player zone coordinates (0-100 range) when logging travel events
    - Added to both major zone changes and subzone changes
    - Stored as `x` and `y` fields in travel event data (rounded to 1 decimal, e.g., 37.4, 78.4)
    - Uses `GetPlayerMapPosition("player")` which returns 0.0-1.0 fractions, converted to zone coordinates
    - Coordinates available in JSON exports but not shown in rendered messages
    - Debug logs show coordinates when debug mode is enabled

## [0.6.1] - 2026-01-17

### Fixed

- **Reputation tier changes now captured** (#30)
    - Pattern matching bug fixed: greedy `.+` was consuming entire string
    - Changed to non-greedy `.+?` to correctly parse "You are now Friendly with X"
    - Now logs tier transitions (Friendly, Honored, Revered, Exalted)

## [0.6.0] - 2026-01-16

### Changed

- **Reputation changes now aggregate with combat** (#29)
    - Reputation gains/losses during combat are held until the aggregation window closes
    - Multiple rep changes to same faction are summed (e.g., 3 kills = -300 total)
    - Aggregated format: "Reputation: Gelkis +60, Magram -300"
    - Rep changes outside combat still log immediately
    - Vague rep changes (no amount) always log immediately

## [0.5.5] - 2026-01-16

### Added

- **Track reputation decreases** (#28)
    - Now logs reputation losses (e.g., "Reputation with Magram Clan Centaur decreased by 100")
    - Uses `change` field: positive for gains, negative for losses
    - Patterns: "decreased by X" and vague "decreased" messages
    - Legacy `amount` field still supported for old entries

## [0.5.4] - 2026-01-16

### Fixed

- **Target info now captured immediately when command is run** (#27)
    - Previously, target info was read when note was submitted
    - If target died/despawned while writing note, info was lost
    - Now captures name, level, reaction, race, class, and location upfront
    - Target can disappear after command is run and info is still preserved

## [0.5.3] - 2026-01-16

### Fixed

- **Incorrect target.class for NPCs in capture_target** (#26)
    - `UnitClass()` was returning mob name for NPCs
    - Now only sets `class` and `race` for player targets
    - NPCs/mobs will have `class` and `race` omitted from data

## [0.5.2] - 2026-01-16

### Fixed

- **Subzone change now logs when entering/leaving area with no subzone** (#25)
    - Previously, leaving "Sar'theris Strand" for generic "Desolace" wouldn't log
    - Now logs "Entered Desolace (from Sar'theris Strand)." when leaving a named subzone
    - When entering a subzone from generic zone, shows "Entered Sar'theris Strand (from Desolace)."

### Changed

- Reduced subzone debounce from 30 seconds to 10 seconds

## [0.5.1] - 2026-01-16

### Added

- **Subzone change tracking** (#24)
    - Logs when entering a new subzone within the same major zone
    - New `subzone_change` travel action with `subZone` and `fromSubZone` in data
    - Display format: "Entered [Subzone] (from [Previous Subzone])."
    - 30-second debounce per subzone to prevent spam at zone boundaries
    - Listens to `ZONE_CHANGED` event (in addition to existing `ZONE_CHANGED_NEW_AREA`)

## [0.5.0] - 2026-01-16

### Added

- **Profession skill tracking** (#23)
    - Logs skill increases when gathering or crafting
    - New `profession` event type with `skill` and `level` in data
    - Display format: "[Skill] skill increased to [level]" (e.g., "Mining skill increased to 42")
    - Listens to `CHAT_MSG_SKILL` event

## [0.4.3] - 2026-01-16

### Fixed

- Reputation gains now log for "Reputation with X increased" chat messages (previously only matched "Your reputation with X has increased")

## [0.4.2] - 2026-01-16

### Changed

- **Unified aggregation window** (#19)
    - Combat aggregation now spans from combat start through 10s post-combat looting
    - Combat end no longer flushes immediately - starts 10-second timer instead
    - All kills, loot, XP, and money aggregate in the same window
    - Window flushes when: timer expires OR new combat starts
    - Removed separate `pendingLoot`/`pendingMoney` - unified into `combatAgg`

## [0.4.1] - 2026-01-16

### Added

- **Money loot logging** (#1)
    - Logs copper/silver/gold looted from mobs with readable formatting
    - New `money` event type with `copper` amount in data
    - Display format: `Looted: Xg Ys Zc` (e.g., "Looted: 1g 5s 32c")

## [0.4.0] - 2026-01-16

### Added

- **Event-first storage model** (breaking change to SavedVariables format)
    - All journal entries are now stored as structured Lua tables with schema versioning
    - Entry format: `{ v, ts, type, msg, data }` where:
        - `v` = schema version (currently 2)
        - `ts` = ISO 8601 timestamp (e.g., "2026-01-16T19:16:12Z")
        - `type` = event type (quest, loot, death, travel, etc.)
        - `msg` = human-readable message (derived from data)
        - `data` = structured event data (type-specific fields)
    - Message text is now derived from structured data, not the other way around
    - Automatic migration of existing entries on addon load
- **JSON export**
    - New "JSON" button in journal UI exports session as NDJSON (one JSON object per line)
    - Machine-readable format enables automation (n8n, agents, storytelling tools)
    - Each line is a complete, self-contained event object
- Message renderers for all event types ensure consistent text output from structured data
- **Quest location tracking**: Quest accept/turn-in events now include zone and subZone
- **Debug/testing commands**:
    - `/journal undo` - Remove the last entry
    - `/journal clear` - Clear all entries from current session
    - `/journal reset` - End current session and start a fresh one
    - `/journal help` - Show all available commands

### Changed

- Internal `AddEntry` replaced with `AddEvent` for new structured format
- Legacy `AddEntry` preserved as wrapper for backward compatibility
- Event types now use `action` field for sub-types:
    - `quest.action`: "accepted" | "turned_in"
    - `travel.action`: "flight_start" | "flight_end" | "hearth" | "zone_change"
    - `screenshot.action`: "manual" | "capture_scene" | "capture_target"
    - `loot.action`: "loot" | "create" | "craft" | "receive"
- Screenshot events unified: `target` event merged into `screenshot` with `action: "capture_target"`
- Screenshot actions: `manual` (hotkey), `capture_scene` (no target), `capture_target` (with target)
- Target info now nested: `data.target: { name, level, reaction, race, class }`
- All screenshot events include `zone`/`subZone` for panel-level location context
- Screenshot/target entries normalized to use `data.filename` (previously mixed `screenshot`/`filename`)
- Activity events now use `target`/`count` for single-target kills (cleaner than `kills` map)
- Loot events differentiate item sources: looting vs crafting vs creating vs receiving

### Technical

- Schema version field (`v`) enables future migrations
- ISO 8601 timestamps for interoperability
- Event data is authoritative; display text is derived
- Extensible pattern for adding new event types
- Migration backfills action fields and normalizes legacy field names

## [0.3.7] - 2026-01-15

### Added

- Note capture command
    - Slash command `/journal note` to add standalone notes to the journal
    - Multiline text input dialog for longer notes
    - Entry format: "Note: [your note text]"
    - Useful for documenting thoughts, observations, or any text without requiring a target or screenshot

## [0.3.6] - 2026-01-15

### Fixed

- Auto-scroll to bottom now works on first open after UI reload
- Multi-line entries no longer overlap with subsequent entries (dynamic height calculation)

### Changed

- Added spacing between journal entries for better readability (4px gap)
- Non-target screenshot entries now use "Scene:" prefix instead of "Screenshot"

## [0.3.5] - 2026-01-15

### Changed

- Manual capture command now works without a target
    - `/journal capture` can be used to take a screenshot with a note even when no target is selected
    - With target: logs "Spotted: [name] (lvl X) [reaction] [race] [class] note=\"...\" screenshot=..."
    - Without target: logs "Scene: note=\"...\" screenshot=..."
    - Useful for documenting locations, views, or any moment without needing a target

## [0.3.4] - 2026-01-15

### Added

- Manual target capture
    - Slash command `/journal capture` or `/journal capture-target` to manually document targets
    - Captures target info: name, level, reaction (friendly/neutral/hostile), race, class
    - Takes screenshot immediately when command is run
    - Shows input dialog to add optional note
    - Entry format: "Spotted: [name] (lvl [X]) [reaction] [race] [class] note=\"[note]\" screenshot=[filename]"
    - Useful for documenting rare mobs, NPCs, or interesting encounters

## [0.3.3] - 2026-01-15

### Added

- Reputation gain tracking
    - Detects reputation changes via `CHAT_MSG_COMBAT_FACTION_CHANGE` event
    - Logs "Reputation with [Faction] increased by [amount]" for specific gains
    - Logs "Reputation with [Faction] increased" for vague increases
    - Tracks tier changes: "Reputation tier: [Tier] with [Faction]" when reaching new standing

## [0.3.2] - 2026-01-15

### Added

- Export session functionality
    - Export button in journal UI to export selected session as plain text
    - Opens a scrollable dialog with formatted session text (character name, time range, all entries with timestamps)
    - Text is pre-selected and copyable via Cmd+C/Ctrl+C
    - Dialog is movable and can be closed with Escape or Close button

## [0.3.1] - 2026-01-15

### Added

- Screenshot logging
    - Detects screenshots via `SCREENSHOT_SUCCEEDED` event
    - Logs screenshot filename in standard WoW format: "Screenshot: WoWScrnShot_MMDDYY_HHMMSS.jpg"
    - Helps locate screenshots later by matching journal entries to screenshot files

## [0.3.0] - 2026-01-15

### Added

- Zone change tracking with subzones
    - Travel entries now show "Traveled to [Zone - Subzone] from [Zone - Subzone]"
    - Includes subzone information when available (e.g., "Thousand Needles - Freewind Post")
- Hearthstone detection and logging
    - Detects hearthstone casts via `UNIT_SPELLCAST_SUCCEEDED`
    - Logs "Hearth to [Zone - Subzone] from [Zone - Subzone]" when zone changes within 90s of cast
- Flight origin node names
    - Flight start entries now show actual node name (e.g., "Ratchet") instead of zone name (e.g., "The Barrens")
    - Example: "Started flying to Orgrimmar from Ratchet" instead of "Started flying to Orgrimmar from The Barrens"

### Fixed

- Flight landing detection now works reliably with delayed checks and zone change fallback

## [0.2.0] - 2026-01-15

### Added

- Flight path tracking with proper start/land detection
    - Logs "Started flying to [destination] from [origin]" when flight begins
    - Logs "Landed in [zone]" when flight ends
    - Prevents incorrect zone change entries during flight
    - Uses `TakeTaxiNode` hook and `PLAYER_CONTROL_LOST/GAINED` events
- Character name in session labels (e.g., "Tallimantra-Realm 2026-01-15 12:21 - current")
- Session reuse: same character + same day = same session (no new session on reload/relog)
- Quest turn-in name detection from system chat messages
- Combat-session aggregation for kills/XP (groups per combat, not time-based)
- Loot merge window: same item within 10 seconds gets grouped
- Loot flush on quest accept/turn-in to prevent cross-quest grouping
- Level-up event logging

### Fixed

- Quest turn-in names now show correctly (was showing only ID)
- Kill tracking now only counts player kills (was counting all nearby NPC deaths)
- Loot aggregation timeout on quest events
- Zone change spam during flights

### Changed

- Aggregation changed from time-based (60s) to combat-session based
- Kills and XP now combined into single "Killed: X | Gained Y XP" entries
- Session creation: auto-splits by character+day instead of login/logout

## [0.1.0] - 2026-01-15

### Added

- MVP session-based journal logging
- Quest accept/turn-in tracking
- Kill and XP tracking
- Loot tracking
- Death tracking with source info
- Basic UI with session selector
- `/journal` slash command
- `/journal debug` toggle
