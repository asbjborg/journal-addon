# Story-writer

Mini workflow-runner for journal addon: step templates + workflow instances. No n8n.

## Structure

- **steps/** – Reusable step templates (read-file, parse-jsonl, collect-quest-ids, fetch-wowhead-quests, parse-wowhead-html).
- **workflows/** – One folder per workflow; each runs a pipeline of steps with config.

## Run story-beat-writer

From this directory:

```bash
npm run story-beat-writer
```

Or:

```bash
node workflows/story-beat-writer/index.js
```

Default config uses `workflows/story-beat-writer/examples` (Thunderstrike/Maskine/session-01). Override via env or a **.env** file.

**Env file:** Put a `.env` in `workflows/story-beat-writer/` (or in the directory you run from). Copy from `.env.example` and edit. Variables:

- `PATH_TO_SESSIONS` – base path to session folders (realm/character/session-N/session-N.jsonl)
- `REALM`, `CHARACTER_NAME`, `SESSION`

Pipeline: read session JSONL → parse events → collect quest IDs → fetch Wowhead HTML per quest → **enrich** each quest event with Wowhead data → output **JSONL** (one line per event). Quest events get `data.questContext` with the parsed Wowhead object (title, description, rewards, NPCs, etc.) or `{ questID, error }` if fetch/parse failed. Non-quest lines are unchanged.

To save enriched output: `npm run story-beat-writer > session-01-enriched.jsonl`

**Note:** Live Wowhead may redirect or return non-HTML; for reliable parsing use cached HTML or run against examples in `workflows/story-beat-writer/examples/wowhead/`.
