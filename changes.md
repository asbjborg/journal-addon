# Changelog

## [0.4.0] - 2026-01-16

### Added

- **Event-first storage model** (breaking change to SavedVariables format)
    - All journal entries are now stored as structured Lua tables with schema versioning
    - Entry format: `{ v, ts, type, msg, data }` where:
        - `v` = schema version (currently 1)
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

### Changed

- Internal `AddEntry` replaced with `AddEvent` for new structured format
- Legacy `AddEntry` preserved as wrapper for backward compatibility
- Event types now use `action` field for sub-types:
    - `quest.action`: "accepted" | "turned_in"
    - `travel.action`: "flight_start" | "flight_end" | "hearth" | "zone_change"
    - `screenshot.action`: "taken" | "scene_note"
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
