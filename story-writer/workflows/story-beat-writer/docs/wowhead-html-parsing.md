# Parsing Wowhead quest HTML

Wowhead quest pages (e.g. `https://www.wowhead.com/tbc/quest=570/...`) embed structured data in the HTML. This doc describes where to find each field so we can parse them in the story-writer workflow (or elsewhere) without a browser.

## Data sources (in order of use)

### 1. Quest ID and page type

- **Script block**: `<script type="application/json" id="data.page.info">`
- **JSON**: `{ "entityId": 570, "entityType": 5 }`
- **Use**: `entityId` = quest ID; `entityType: 5` = quest.

### 2. Title and short description

- **Option A – ld+json**: `<script type="application/ld+json">`
  - `name` = quest title
  - `description` = short summary (often "Who wants X. A level N Zone Quest. Rewards.")
- **Option B – meta**: `<meta name="description" content="...">` and `<title>Quest Name - Quest - TBC Classic</title>`
  - Title: strip ` - Quest - TBC Classic` (or similar) from `<title>`.
  - Short description: use `content` of `meta[name="description"]` (decode `&apos;` etc.).

### 3. Quick facts (level, side, start/end NPC, sharable, difficulty, patch)

- **Script**: `WH.markup.printHtml("...", "infobox-contents-0", ...)`
- **Content** is a custom markup string. Example:

  `[ul][li]Level: 38[/li][li]Requires level 33[/li][li]Side: [span class=icon-horde]Horde[/span][/li][li][icon name=quest-start]Start: [url=/tbc/npc=2465/far-seer-mokthardin]Far Seer Mok'thardin[/url][/icon][/li][li][icon name=quest-end]End: [url=/tbc/npc=2465/far-seer-mokthardin]Far Seer Mok'thardin[/url][/li][li]Sharable[/li][li]Difficulty: ...[/li][li]Added in patch ...[/li][/ul]`

- **Parse**:
  - **Level**: `[li]Level: N[/li]` → N.
  - **Requires level**: `[li]Requires level N[/li]` → N.
  - **Side**: text inside `[span class=icon-horde]` or `icon-alliance` (e.g. "Horde", "Alliance").
  - **Start NPC**: after `[icon name=quest-start]Start: [url=...]` take the link text until `[/url]`; NPC ID from `url=/tbc/npc=ID/...`.
  - **End NPC**: same after `[icon name=quest-end]End: [url=...]`.
  - **Sharable**: presence of `[li]Sharable[/li]` or `Not sharable`.
  - **Difficulty**: optional; numbers appear after `Difficulty: [color=...]`.
  - **Patch**: optional; after `Added in patch [acronym="..."]`.

### 4. XP and money rewards (scaling)

- **Script**: `WH.Wow.Quest.setupScalingRewards({...});`
- **JSON** (example):  
  `{ "minLevel": 38, "maxLevel": 38, "xp": { "multiplier": 1, "levels": { "38": 2900 } }, "coin": { "rewardAtCap": 1740, "multiplier": 1, "levels": { "38": 0 } } }`
- **Use**:
  - **XP**: pick from `xp.levels[level]` for the quest level (or first key).
  - **Money**: `coin.rewardAtCap` (at cap) or `coin.levels[level]` (often 0 if no copper reward).

### 5. Description, objectives, completion (body text)

- **Description**: `<h2 ...>Description</h2>` – following content until the next `<h2>` (strip HTML, decode entities).
- **Objectives**: if present, section with heading "Objectives" (or similar) before Rewards.
- **Completion**: `<h2 ...>Completion</h2>` then often `<div id="...-completion" style="display: none">...</div>`. Text inside that div (strip HTML, decode `&lt;name&gt;` etc.).

### 6. Rewards (items)

- **Section**: after `<h2>Rewards</h2>` / "You will receive:"
- **Items**: links `<a href="/tbc/item=ID/slug">Item Name</a>` in that section (or table with class `icontab`).
- **Script**: `g_items.createIcon(ID, quantity, "1")` – item ID and quantity.
- **Dedupe**: same item can appear in link and in `createIcon`; use one source (e.g. links + text for name).

### 7. Gains (XP display, reputation)

- **Section**: after `<h2>Gains</h2>` / "Upon completion of this quest you will gain:"
- **XP**: often filled by script into `id="quest-reward-xp"`; numeric value can also come from `setupScalingRewards` (see above).
- **Reputation**: list items like "500 reputation with <a ...>Thunder Bluff</a>". Parse number and link text (faction name).

### 8. Location / zone

- **Meta description** often includes zone: "A level 38 **Stranglethorn Vale** Quest" or "A level 37 **Thunder Bluff** Quest".
- **data.mapper.objectiveTerms**: template strings like "This quest starts in $$" – the `$$` is replaced with zone names; useful for UI, less so for a single "location" string. Prefer meta or body text.

## Output shape (suggested for quest context)

- `questID`, `title`, `description` (short), `descriptionLong`, `objectives`, `completionText`
- `level`, `requiredLevel`, `side`, `startNpc` (`id`, `name`), `endNpc` (`id`, `name`), `sharable`, `patch`
- `rewards`: `xp`, `money`, `items` (`[{ itemId, quantity, name }]`), `reputation` (`[{ faction, amount }]`)
- `location` / `zone` (from meta or description)

## Notes

- All script content may be on one long line; use regex that allows `\n` and escaped quotes.
- Decode HTML entities: `&apos;` → `'`, `&lt;` → `<`, `&gt;` → `>`, `&amp;` → `&`, etc.
- NPC "start" and "end" can be the same NPC (same url and name in both li items).
