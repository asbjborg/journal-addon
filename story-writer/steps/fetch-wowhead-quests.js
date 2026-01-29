const https = require('https');
const { parseQuestHtml } = require('./parse-wowhead-html.js');

/**
 * For each quest ID: GET Wowhead page, parse HTML, collect parsed quests.
 * Input: { config, questIds }
 * Params: { baseUrl } (default https://www.wowhead.com/tbc/quest=)
 * Output: { config, quests } (array of parsed quest objects)
 */
async function run(input, params = {}) {
  const { config, events, questIds } = input;
  const baseUrl = params.baseUrl || 'https://www.wowhead.com/tbc/quest=';
  if (!Array.isArray(questIds)) throw new Error('fetch-wowhead-quests: missing questIds array');

  const quests = [];
  for (const qid of questIds) {
    const url = `${baseUrl}${qid}`;
    const html = await fetchUrl(url);
    const parsed = parseQuestHtml(html);
    if (parsed.error) {
      quests.push({ questID: qid, error: parsed.error });
    } else {
      quests.push(parsed);
    }
  }
  return { config, events, quests };
}

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
      })
      .on('error', reject);
  });
}

module.exports = { run };
