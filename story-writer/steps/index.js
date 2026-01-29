const readFile = require('./read-file.js');
const parseJsonl = require('./parse-jsonl.js');
const collectQuestIds = require('./collect-quest-ids.js');
const fetchWowheadQuests = require('./fetch-wowhead-quests.js');
const enrichJsonl = require('./enrich-jsonl.js');
const { parseQuestHtml } = require('./parse-wowhead-html.js');

/**
 * Run a pipeline of steps. Each step receives (input, params) and returns output for next step.
 * @param {Array<{ step: { run: Function }, params?: object }>} steps
 * @param {object} initialInput
 * @returns {Promise<object>} Final output
 */
async function run(steps, initialInput = {}) {
  let current = initialInput;
  for (const { step, params = {} } of steps) {
    current = await Promise.resolve(step.run(current, params));
  }
  return current;
}

module.exports = {
  run,
  readFile,
  parseJsonl,
  collectQuestIds,
  fetchWowheadQuests,
  enrichJsonl,
  parseQuestHtml,
};
