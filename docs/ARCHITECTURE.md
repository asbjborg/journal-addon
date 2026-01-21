# JournalingAddon Architecture

This addon uses a simple module split with toc load order. New features are added
as new Lua files and listed in `JournalingAddon.toc`.

## Layout

Core (loaded first):
- `JournalingAddon/core/Namespace.lua` (shared `Journal` table + event bus)
- `JournalingAddon/core/Util.lua` (helpers: timestamps, JSON, money formatting)
- `JournalingAddon/core/Storage.lua` (SavedVariables, sessions, events, schema reset)
- `JournalingAddon/core/Renderers.lua` (message renderers registry)
- `JournalingAddon/core/Events.lua` (WoW events -> internal bus)

Features (loaded after core):
- `JournalingAddon/features/*.lua` (quest, travel, combat, screenshots, notes, etc.)

UI (loaded last):
- `JournalingAddon/JournalUI.lua`

## Event Lifecycle

1. `core/Events.lua` registers WoW events and calls `Journal.Emit(event, ...)`.
2. Feature modules register handlers via `Journal.On("EVENT", fn)`.
3. Handlers call `Journal:AddEvent(type, data)` to create a journal entry.
4. `Journal:AddEvent` uses the renderer for `type` to derive `msg`.
5. UI reads `entry.msg` (the derived message) and never infers from `data`.

## Renderer Contract

- `data` is the source of truth.
- `msg` is derived by a renderer and cached on the event.
- UI should use `msg` and not attempt to rebuild it.

## Alpha Schema Reset Policy

Before v1.0.0, schema changes reset all journal data.

On addon load:
- If `JournalDB.schemaVersion ~= Journal.CURRENT_SCHEMA`, the addon resets storage.
- In debug mode, old data is moved to `JournalDB.backup_<timestamp>`.
- A fresh session is started.

No per-entry migrations are used during alpha.

## Adding a New Feature

1. Create a new file under `JournalingAddon/features/`.
2. Register handlers with `Journal.On(...)`.
3. Register a renderer with `Journal:RegisterRenderer(type, fn)`.
4. Add the new file to `JournalingAddon.toc` under the features section.
