# Changelog

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
