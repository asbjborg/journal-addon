/**
 * Collect unique quest IDs from events (type=quest, action=accepted|turned_in).
 * Input: { config, events }
 * Output: { config, questIds } (array of string quest IDs)
 */
function run(input, _params) {
  const { config, events } = input;
  if (!Array.isArray(events)) throw new Error('collect-quest-ids: missing events array');
  const questIds = new Set();
  for (const e of events) {
    if (e?.type !== 'quest') continue;
    const action = e?.data?.action;
    if (action !== 'accepted' && action !== 'turned_in') continue;
    const id = e?.data?.questID;
    if (typeof id === 'number' || typeof id === 'string') {
      questIds.add(String(id));
    }
  }
  return { config, events, questIds: [...questIds] };
}

module.exports = { run };
