# Dummy Data Notes

This directory contains representative dummy journal output generated from the current codebase behavior (as of v0.6.15). The data reflects actual event structures, including edge cases and potentially awkward behaviors that exist in the current implementation.

## File Structure

- `session-01.jsonl` - Comprehensive coverage of all event types (JSONL format)
- `session-01.txt` - Human-readable rendered output for session 1
- `session-02.jsonl` - Edge cases and specific scenarios (JSONL format)
- `session-02.txt` - Human-readable rendered output for session 2

## Event Coverage

### Session 1: Comprehensive Coverage

**Core Activity Chunks:**
- Multiple kills with aggregated XP and loot (Feral Dragonhawk Hatchling x3)
- Single kill activity chunk (Darnassian Scout, Manawraith)
- Activity chunk hitting hard cap (3 minutes) - Grimscale Forager at 15:00:45
- Activity chunk with multiple target types (Grimscale Forager x2, Grimscale Scout x1)

**Hard Cut Events:**
- Quest accept (multiple examples)
- Quest turn-in with XP and reputation
- Level-up (with auto screenshot)
- Screenshot (manual, target capture, scene capture)
- Zone change and subzone change
- System event (session start)

**XP Sources:**
- Kill XP (aggregated in activity chunks)
- Quest XP (standalone after turn-in)
- Discovery XP (with suppression - note that standalone XP events may still appear)
- Standalone XP events (isolated XP gains)

**Loot Cases:**
- Loot from kills (aggregated in activity chunks)
- Late-arriving loot after hard cut (Mana Residue x3 after level-up)
- Money loot (aggregated and standalone)
- Item "receive" cases (Heavy Linen Bandage - not from kills)
- Craft actions (Linen Cloth)
- Create actions (Minor Healing Potion)

**Other Events:**
- Profession/skill-ups (aggregated: Wands 16-22, 23-26, 27-29; single: Wands 30, Defense 32)
- Reputation changes (aggregated in activity chunks, standalone vague changes, tier changes)
- Travel events (zone change, subzone change, flight start/end, hearth, boundary noise)
- Death events (with source, spell, level)
- Notes (manual notes)
- Discovery events (zone discovery with XP)

### Session 2: Edge Cases

**Hard Cap Window:**
- Activity chunk hitting 3-minute hard cap (Grimscale Forager at 15:00:45, duration: 180s)

**Resume Window:**
- Activity chunk timing out after 30s idle (multiple examples)

**Late-Arriving Loot:**
- Loot appearing after level-up hard cut (Mana Residue x2, Money 5c at 15:09:05)
- These appear immediately without duration (within 10s hard flush window)

**Quest Rewards:**
- Quest turn-in with immediate loot logging (Grimscale Murloc Head x5, Money 50c)
- Quest rewards bypass activity chunk aggregation

**Subzone Ping-Pong Suppression:**
- Multiple rapid subzone changes (Sunstrider Isle ↔ Tranquil Shore)
- Boundary noise event logged on first ping-pong detection
- Subsequent ping-pong transitions suppressed

**Singleton Activity Chunks:**
- Single kill chunks that still show duration (may feel awkward but reflects current behavior)
- Example: Grimscale Forager at 15:08:33 with 49s duration

**Standalone XP Events:**
- XP gains that don't belong to any activity chunk
- Examples: 64 XP, 80 XP, 120 XP - these appear as isolated events

**Zero XP Kills:**
- Kill with no XP gain (Rotting Corpse at 15:10:30)
- Still creates activity chunk with loot

**Aggregated Profession:**
- Multiple skill-ups aggregated (Tailoring 45-52 over 8s)

## Event Structure Details

### Common Fields
- `v`: Schema version (currently 3)
- `ts`: ISO 8601 timestamp (YYYY-MM-DDTHH:MM:SS)
- `seq`: Sequence number for stable ordering when timestamps are identical
- `type`: Event type (activity, loot, money, quest, level, etc.)
- `data`: Event-specific data object
- `msg`: Human-readable rendered message

### Activity Events
- Single target: `{target: "Name", count: N, xp: X, duration: D}`
- Multiple targets: `{kills: {name: count, ...}, xp: X, duration: D}`
- Duration in seconds (raw), rendered as "Xm" or "Xs"

### Loot Events
- `action`: "loot", "receive", "craft", or "create"
- `counts`: Object mapping item names to quantities
- `raw`: Array of original loot messages
- `duration`: Optional, present when aggregated over time

### Quest Events
- `action`: "accepted" or "turned_in"
- `questID`: Numeric quest ID
- `title`: Quest title
- `xp`: Optional XP reward (turn-in only)
- `money`: Optional money reward in copper (turn-in only)
- `zone`/`subZone`: Location where quest was accepted/turned in

### Travel Events
- `action`: "zone_change", "subzone_change", "flight_start", "flight_end", "hearth", "boundary_noise"
- Zone/subzone information
- Coordinates (`x`, `y`) when available
- Flight hops array for multi-hop flights

### Screenshot Events
- `action`: "manual", "capture_target", or "capture_scene"
- `filename`: Screenshot filename
- `note`: Optional note text
- `target`: Optional target info (for capture_target)

## Known Behaviors (Not Bugs)

1. **Standalone XP Events**: XP from discoveries and quests may appear as separate events even when logged in discovery/quest events. This reflects current suppression logic.

2. **Singleton Chunks with Duration**: Single-kill activity chunks still show duration, which may feel awkward but is consistent with the aggregation system.

3. **Late Loot Without Duration**: Loot arriving within 10s of a hard flush appears immediately without duration, reflecting the hard flush window behavior.

4. **Quest Reward Loot**: Quest rewards are logged immediately, bypassing activity chunk aggregation, which is intentional.

5. **Subzone Ping-Pong**: First ping-pong transition logs boundary_noise, subsequent ones are suppressed within 5s window.

6. **Event Reordering**: Quest turn-in events may reorder related XP/reputation events to appear before the quest event in the log.

7. **Timestamp Sharing**: Events flushed from the same activity chunk share the same timestamp and sequence number, ensuring they appear together when sorted.

## Usage

These files can be used for:
- Defining event contracts for LLM ingestion
- Creating golden examples for testing
- Validating n8n → LLM → comic pipeline
- Preventing future regressions
- Documentation and schema generation

The JSONL format (newline-delimited JSON) is suitable for streaming processing and line-by-line parsing.
