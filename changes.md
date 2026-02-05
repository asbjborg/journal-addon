# Changelog

## [0.6.24] - 2026-02-05

### Changed

- **Clear/reset and singleton chunk polish** (#60, #50)
    - `/journal clear` now resets any in-flight activity chunk/timers and adds a system marker entry: `Entries cleared. Starting new session.`
    - `/journal reset` now starts the new session with the same `Entries cleared. Starting new session.` marker message
    - Single-kill activity chunks no longer show duration text
    - Single-item loot chunks (one item type, count 1) no longer show duration text

## [0.6.23] - 2026-01-30

### Added

- **Party event logging** (#51)
    - Logs party-related events: invited to party (by whom), accepted party invite, left party, removed from party, disbanded party, removed member from party, party member joined, party member left
    - Uses `PARTY_INVITE_REQUEST` and `PARTY_MEMBERS_CHANGED` (TBC 20505); `CHAT_MSG_SYSTEM` for "You have invited", "You leave the group", "You have been removed from the group", "Your group has been disbanded", "You have removed [name] from the group"
    - New feature module `features/Party.lua` with renderer; follows same pattern as Quest.lua and Travel.lua

## [0.6.22] - 2026-01-29

### Fixed

- **Activity chunk before death in timeline** (#59)
    - Death is now a hard cut event: the activity chunk (kills, loot, XP from the combat before death) is flushed before the death event is added, so the timeline shows the activity chunk before "Died to ..." instead of after

## [0.6.21] - 2026-01-29

### Changed

- **Optional startTs/endTs span fields on activity chunk events** (#54)
    - Activity chunk events (`activity`, `loot`, `money`, `reputation`) now include optional `startTs` and `endTs` (ISO 8601) in event data when the chunk has a start time
    - Enables downstream tooling to use explicit temporal spans without deriving from duration
    - `ts` remains insert time; `duration` is preserved; schema version stays v=3
    - `Journal.ISOTimestamp(unixTime)` now accepts an optional Unix timestamp for formatting

## [0.6.20] - 2026-01-29

### Fixed

- **Skill level up aggregator fails to chunk subsequent skillups** (#52)
    - Subsequent skill chunks (after the first 10s window) now show range and duration correctly
    - Last flushed end level per skill is persisted across chunks; when a new chunk starts for the same skill, start level is taken from the previous chunk’s end (e.g. first chunk "2-8 (over 24s)", second chunk "8-12 (over Xs)")
    - Resolves issue where the second entry showed "Swords skill increased to 12" instead of "from 8-12 (over Xs)"

## [0.6.19] - 2026-01-29

### Fixed

- **Text and JSON export timeline order** (#58)
    - Export (text and JSON) now outputs entries in the same chronological order as the addon UI (sorted by timestamp, then sequence)
    - Previously exports used raw insertion order, so events stored out of timestamp order (e.g. quest turn-ins, travel, reputation) could appear in the wrong order in exported output

## [0.6.18] - 2026-01-29

### Added

- **story-writer workflow runner** – Node.js workflow runner in `story-writer/` (replaces n8n). Step templates: read-file, parse-jsonl, collect-quest-ids, fetch-wowhead-quests, enrich-jsonl. First workflow: **story-beat-writer** (read session JSONL → fetch Wowhead per quest → enrich quest events with `data.questContext` → output JSONL). Config via `.env`; docs and output example in `story-writer/workflows/story-beat-writer/docs/`. Addon and story-writer are versioned together.

### Removed

- **n8n workflow** – `n8n/workflows/journalAddon.json` removed; automation lives in story-writer.
- **Root schemas and Wowhead examples** – Moved to `story-writer/workflows/story-beat-writer/schemas/` and `examples/`; single source of truth under story-writer.

### Documentation

- **README, ARCHITECTURE, docs** – Automation section points to story-writer; ARCHITECTURE notes exported data is consumed by story-writer (no n8n). Dummy-data notes and generate-dummy-data command updated for story-writer workflows.
- **.gitignore** – Ignore `.env` and `story-writer/workflows/story-beat-writer/.env`.

## [0.6.17] - 2026-01-25

### Enhanced

- **Money events now display duration like loot events** (#57)
    - Money events aggregated over time now show duration: "Looted: Xg Ys Zc (over Xm)" or "(over Xs)"
    - Duration formatting matches loot events: "Xm" for >= 60s, "Xs" for < 60s
    - Money events logged immediately (not aggregated) do not show duration
    - Improves consistency between money and loot display since they're aggregated in the same activity chunk

## [0.6.16] - 2026-01-22

### Fixed

- **Party member loot incorrectly counted as player loot** (#53)
    - Loot received by party members is now filtered out and not recorded in the journal
    - Uses WoW's global format strings (LOOT_ITEM_SELF, LOOT_ITEM, etc.) for localization-safe pattern matching
    - Only records loot where the player is the recipient
    - Handles realm suffixes and name variations correctly
    - Resolves issue where party member loot (e.g., "Zaraboz receives loot: [Hezrul's Head]") was being counted as player loot

## [0.6.15] - 2026-01-21

### Enhanced

- **Retroactive loot aggregation in hard flush window** (#47)
    - Late-arriving loot (within 10 seconds after hard flush) now retroactively updates the last flushed loot entry
    - All loot from the same activity chunk is combined into a single entry, even if some arrives after the hard flush event
    - Improves readability by keeping all loot together instead of splitting it across multiple entries
    - Example: Loot received 2 seconds after screenshot now appears in the same entry as loot from the flushed chunk

## [0.6.14] - 2026-01-21

### Fixed

- **Loot entries appear out of order relative to their source kills** (#47)
    - Loot entries now appear immediately after their source kill entries
    - All entries flushed from the same activity chunk (kill, loot, money, rep) now use the same timestamp
    - Hard flush window (10 seconds) prevents new chunks from starting immediately after hard flush events
    - Late-arriving loot within the window is captured immediately without duration
    - Resolves issue where loot appeared separated from kills by other events (e.g., after level-up hard flush)
    - Ensures proper chronological ordering so loot always appears right after its source kill

## [0.6.13] - 2026-01-20

### Fixed

- **Discovery XP duplication** (#46)
    - Discovery XP no longer appears twice in journal entries
    - Discovery XP is tracked when discovery event is created
    - Duplicate `PLAYER_XP_UPDATE` events that match discovery XP are suppressed (within 3 seconds)
    - Only the discovery event shows XP, not a separate "Gained XP" entry
    - Resolves issue where discovery XP appeared in both discovery event and standalone XP event

## [0.6.12] - 2026-01-20

### Fixed

- **XP totals incorrect in activity chunk (double counting)** (#48)
    - XP totals in activity chunks now correctly reflect actual kill XP
    - Use `CHAT_MSG_COMBAT_XP_GAIN` as canonical source for kill XP (explicitly tells kill XP from "dies" messages)
    - Suppress duplicate `PLAYER_XP_UPDATE` events that match recent kill XP (within 2 seconds)
    - Non-kill XP (quest rewards, discovery, etc.) still handled via `PLAYER_XP_UPDATE`
    - Resolves issue where XP totals were inflated (e.g., 224 XP instead of 160 for 2 mobs)

## [0.6.11] - 2026-01-20

### Fixed

- **Out-of-order events (chunk timestamping)** (#45)
    - Events now appear in correct chronological order in the UI
    - Added sequence counter (`seq`) to track insertion order for stable sorting
    - Events are sorted by `(ts, seq)` when displayed, ensuring proper ordering even when inserted out of timestamp order
    - Event timestamps (`ts`) always reflect "time of insert" (current time when `AddEvent` is called)
    - Design principle: future span timestamps (startTs/endTs) would be stored in event data only, never as event `ts`
    - Resolves issue where later events could appear before earlier events in the journal

## [0.6.10] - 2026-01-20

### Changed

- **Skill up aggregation** (#44)
    - Skill ups for the same skill within 10 seconds are now aggregated into a single entry
    - Display format: `[Skill] skill increased from [start]-[end] (over [duration]s)`
    - Example: `Wands skill increased from 7-9 (over 3s)`
    - Uses rolling window (10 seconds) that resets/extends on each new skill up
    - Reduces log spam from rapid skill increases during crafting/gathering
    - Skill aggregation is flushed on logout

## [0.6.9] - 2026-01-20

### Added

- **Zone discovery logging** (#43)
    - New `discovery` event type for zone/subzone discovery
    - Logs when player discovers a new area (from "Discovered [Zone Name]: X experience gained" system message)
    - Includes discovered zone name, current zone/subzone, XP gained, and coordinates
    - Display format: "Discovered: [Zone Name] (X XP)"
    - Important for downstream storytelling to track exploration milestones
    - Discovery events are hard cut events (flush activity chunks)

## [0.6.8] - 2026-01-20

### Changed

- **Unified time-based activity chunk system** (#42)
    - Replaced dual aggregation system (`combatAgg` + `lootAgg`) with unified `activityChunk`
    - Activity chunk aggregates kills, XP, loot, money, and reputation using time-based logic
    - **Resume window (30s)**: Activity continues to aggregate if new activity happens within 30 seconds of previous activity
    - **Hard cap (3m)**: Chunk is force-flushed after 3 minutes, regardless of continued activity
    - Short gaps between combats (leave combat → loot → re-enter combat) no longer split entries
    - Continuous grinding becomes one coherent activity block
    - **Activity chunk flush points:**
        - **Hard cut events** (flush immediately before logging):
            - Quest accepted
            - Quest turned in
            - Level up
            - Screenshot (manual, capture_scene, capture_target)
            - Note
            - Travel: zone change, subzone change, flight start
            - System events (login, logout, AFK, etc.)
        - **Time-based flush:**
            - Resume window expiry (>30s idle since last activity)
            - Hard cap expiry (3m since chunk start)
        - **Session events:**
            - Logout
            - Flight start (explicit flush before logging)
    - Removed combat-based aggregation logic (`inAggWindow`, `inCombat` flags for aggregation)
    - Activity entries now include `duration` field (in seconds) matching loot entries for temporal consistency
    - Duration is only shown if greater than 0 seconds (prevents "(over 0s)" entries)
    - **XP gain handling:**
        - XP gain alone no longer starts activity chunks - chunks are only started by actual activity (kills, loot, money, reputation)
        - XP gain is only added to existing active chunks (with actual activity)
        - Isolated XP gains (quest rewards, zone discovery, etc.) are logged immediately without chunk aggregation
        - Race condition handling: XP gain immediately after level up (within 1 second) is added to the previous activity entry instead of starting a new chunk

### Fixed

- **Timezone issue** - ISO timestamps now use local time instead of UTC to prevent 1-hour timeshift in display

## [0.6.7] - 2026-01-17

### Fixed

- **Loot aggregation flushed on logout** (#40)
    - Loot aggregation window is now flushed when player logs out
    - Prevents loss of pending loot items when logging out during active aggregation window
    - Ensures all loot is saved before session ends

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
