/**
 * Parse Wowhead quest page HTML into a structured object.
 * See workflow/story-beat-writer/docs/wowhead-html-parsing.md for data sources.
 *
 * @param {string} html - Raw HTML from e.g. GET https://www.wowhead.com/tbc/quest=ID/...
 * @returns {object} Parsed quest data (questID, title, description, rewards, npcs, etc.)
 */
function parseQuestHtml(html) {
  if (!html || typeof html !== 'string') {
    return { error: 'Missing or invalid HTML', raw: null };
  }

  const out = {
    questID: null,
    title: null,
    description: null,
    descriptionLong: null,
    objectives: null,
    completionText: null,
    level: null,
    requiredLevel: null,
    side: null,
    startNpc: { id: null, name: null },
    endNpc: { id: null, name: null },
    sharable: null,
    patch: null,
    location: null,
    rewards: {
      xp: null,
      money: null,
      items: [],
      reputation: [],
    },
  };

  const decodeEntities = (s) => {
    if (!s) return s;
    return String(s)
      .replace(/&apos;/g, "'")
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"');
  };

  const stripHtml = (s) => {
    if (!s) return s;
    return String(s)
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  };

  const pageInfoMatch = html.match(/<script[^>]+id="data\.page\.info"[^>]*>([^<]+)<\/script>/);
  if (pageInfoMatch) {
    try {
      const info = JSON.parse(pageInfoMatch[1].trim());
      if (info.entityType === 5) out.questID = info.entityId;
    } catch (_) {}
  }

  const ldJsonMatch = html.match(/<script type="application\/ld\+json">\s*(\{[\s\S]*?\})\s*<\/script>/);
  if (ldJsonMatch) {
    try {
      const ld = JSON.parse(ldJsonMatch[1].trim());
      if (ld.name) out.title = decodeEntities(ld.name);
      if (ld.description) out.description = decodeEntities(ld.description);
    } catch (_) {}
  }

  if (!out.title) {
    const titleMatch = html.match(/<title>([^<]+)<\/title>/);
    if (titleMatch) out.title = decodeEntities(titleMatch[1].replace(/\s*-\s*Quest\s*-\s*.*$/i, '').trim());
  }
  if (!out.description) {
    const metaDesc = html.match(/<meta name="description" content="([^"]*)"/);
    if (metaDesc) out.description = decodeEntities(metaDesc[1]);
  }

  const infoboxMatch = html.match(/WH\.markup\.printHtml\s*\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"infobox-contents-0"/);
  if (infoboxMatch) {
    const markup = infoboxMatch[1].replace(/\\\//g, '/').replace(/\\'/g, "'");
    const levelM = markup.match(/\[li\]Level:\s*(\d+)\[\/li\]/i);
    if (levelM) out.level = parseInt(levelM[1], 10);
    const reqM = markup.match(/\[li\]Requires level\s*(\d+)\[\/li\]/i);
    if (reqM) out.requiredLevel = parseInt(reqM[1], 10);
    const sideHorde = markup.match(/\[span[^]]*icon-horde[^]]*\]([^[]+)\[\/span\]/i);
    const sideAlliance = markup.match(/\[span[^]]*icon-alliance[^]]*\]([^[]+)\[\/span\]/i);
    if (sideHorde) out.side = sideHorde[1].trim();
    else if (sideAlliance) out.side = sideAlliance[1].trim();
    const startM = markup.match(/\[icon name=quest-start\]Start:\s*\[url=\/tbc\/npc=(\d+)\/[^\]]+\]([^[]+)\[\/url\]/i);
    if (startM) {
      out.startNpc.id = parseInt(startM[1], 10);
      out.startNpc.name = decodeEntities(startM[2].trim());
    }
    const endM = markup.match(/\[icon name=quest-end\]End:\s*\[url=\/tbc\/npc=(\d+)\/[^\]]+\]([^[]+)\[\/url\]/i);
    if (endM) {
      out.endNpc.id = parseInt(endM[1], 10);
      out.endNpc.name = decodeEntities(endM[2].trim());
    }
    out.sharable = /\[li\]Sharable\[\/li\]/i.test(markup);
    const patchM = markup.match(/Added in patch \[acronym="[^"]*"\]([^[]+)\[\/acronym\]/i);
    if (patchM) out.patch = patchM[1].trim();
  }

  const scalingMatch = html.match(/WH\.Wow\.Quest\.setupScalingRewards\s*\(\s*(\{[^)]+\})\s*\)/);
  if (scalingMatch) {
    try {
      const scaling = JSON.parse(scalingMatch[1]);
      const levels = scaling.xp?.levels;
      if (levels && typeof levels === 'object') {
        const firstLevel = Object.keys(levels)[0];
        if (firstLevel) out.rewards.xp = parseInt(levels[firstLevel], 10);
      }
      if (scaling.coin) {
        out.rewards.money = scaling.coin.rewardAtCap != null
          ? parseInt(scaling.coin.rewardAtCap, 10)
          : null;
        const coinLevels = scaling.coin?.levels;
        if (coinLevels && typeof coinLevels === 'object' && out.rewards.money == null) {
          const first = Object.keys(coinLevels)[0];
          if (first) out.rewards.money = parseInt(coinLevels[first], 10) || null;
        }
      }
    } catch (_) {}
  }

  const descSection = html.match(/<h2[^>]*>\s*Description\s*<\/h2>\s*([\s\S]*?)(?=<h2[^>]*>|$)/i);
  if (descSection) {
    out.descriptionLong = decodeEntities(stripHtml(descSection[1])).trim() || null;
  }

  const completionMatch = html.match(/<h2[^>]*>[\s\S]*?Completion[\s\S]*?<\/h2>[\s\S]*?<div[^>]*id="[^"]*-completion"[^>]*>([\s\S]*?)<\/div>/i);
  if (completionMatch) {
    out.completionText = decodeEntities(stripHtml(completionMatch[1])).trim() || null;
  }

  const rewardsIdx = html.indexOf('Rewards</h2>');
  const rewardsSection = rewardsIdx >= 0 ? html.slice(rewardsIdx + 12, rewardsIdx + 4000) : null;
  if (rewardsSection) {
    const iconRe = /g_items\.createIcon\((\d+),\s*(\d+)/g;
    let iconM;
    const iconIds = new Set();
    while ((iconM = iconRe.exec(rewardsSection)) !== null) {
      const id = parseInt(iconM[1], 10);
      const qty = parseInt(iconM[2], 10);
      if (qty < 1 || iconIds.has(id)) continue;
      iconIds.add(id);
      const nameMatch = rewardsSection.match(new RegExp(`href="/tbc/item=${id}/[^"]*"[^>]*>([^<]+)<`));
      const name = nameMatch ? decodeEntities(nameMatch[1].trim()) : null;
      out.rewards.items.push({ itemId: id, quantity: qty, name });
    }
    if (out.rewards.items.length === 0) {
      const itemLinkRe = /href="\/tbc\/item=(\d+)\/[^"]*"[^>]*>([^<]+)</g;
      let m;
      const seen = new Set();
      while ((m = itemLinkRe.exec(rewardsSection)) !== null) {
        const id = parseInt(m[1], 10);
        if (seen.has(id)) continue;
        seen.add(id);
        const iconRe = new RegExp(`g_items\\.createIcon\\(${id},\\s*(\\d+)`, 'g');
        const iconM = iconRe.exec(html);
        const qty = iconM ? parseInt(iconM[1], 10) : 1;
        out.rewards.items.push({ itemId: id, quantity: qty, name: decodeEntities(m[2].trim()) });
      }
    }
  }

  const gainsIdx = html.indexOf('Gains</h2>');
  const gainsSection = gainsIdx >= 0 ? html.slice(gainsIdx + 10) : null;
  if (gainsSection) {
    const repRe = /(?:<span[^>]*>)?(\d+)(?:<\/span>)?\s*reputation with\s*<a[^>]*>([^<]+)</gi;
    let m;
    while ((m = repRe.exec(gainsSection)) !== null) {
      out.rewards.reputation.push({
        amount: parseInt(m[1], 10),
        faction: decodeEntities(m[2].trim()),
      });
    }
  }

  if (out.description) {
    const locM = out.description.match(/A level \d+ (\w+(?:\s+\w+)*) Quest/i);
    if (locM) out.location = locM[1].trim();
  }

  return out;
}

module.exports = { parseQuestHtml };
