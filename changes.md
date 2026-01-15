# Changelog

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
