/**
 * Enrich quest events with Wowhead data. Adds data.questContext on each quest event.
 * Input: { config, events, quests } (quests = array from fetch-wowhead-quests)
 * Output: { config, events } (same events, quest lines have data.questContext = Wowhead parsed or { error })
 */
function run(input, _params) {
  const { config, events, quests } = input;
  if (!Array.isArray(events)) throw new Error('enrich-jsonl: missing events array');
  if (!Array.isArray(quests)) throw new Error('enrich-jsonl: missing quests array');

  const byQuestId = new Map();
  for (const q of quests) {
    const id = q.questID != null ? String(q.questID) : null;
    if (id) byQuestId.set(id, q);
  }

  const enriched = events.map((event) => {
    if (event?.type !== 'quest' || event?.data?.questID == null) return event;
    const questId = String(event.data.questID);
    const questContext = byQuestId.get(questId) ?? null;
    return {
      ...event,
      data: {
        ...event.data,
        questContext,
      },
    };
  });

  return { config, events: enriched };
}

module.exports = { run };
