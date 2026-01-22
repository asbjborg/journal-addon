# Generate representative dummy data (so we cover full spectrum)

Generate **dummy sessions** from the current codebase that cover the full event spectrum exactly as emitted today (no normalization), so we can validate schema + n8n + LLM prompts.

## Deliverables

1. `session-01.jsonl` + `session-01.txt`: a “normal” session that hits most event types.
2. `session-02.jsonl` + `session-02.txt`: an “edge case torture test” session.
3. `notes.md`: explains what each segment is testing and which edge-cases are included.

## Coverage checklist

* Activity chunks: multi-kill + single-kill, resume window behavior, hard cap behavior
* Loot: kill-loot, late loot after hard cuts, money, and “receive item” vs “loot” patterns
* XP sources: kill XP vs quest XP vs discovery XP vs standalone XP
* Hard cuts: quest accept/turn-in, level-up + screenshot, travel zone/subzone, notes, system
* Reputation changes (positive/negative), profession skill-ups (aggregated + single), death event
* Travel noise: subzone ping-pong suppression
* Ensure fields match current implementation: `v`, `ts`, `seq`, `type`, `data`, `msg`

## Important

* Use realistic timestamps and seq increments.
* Keep shapes identical to codebase output.
* Include a few known “awkward” cases (if they still exist) so we can confirm downstream handling.
