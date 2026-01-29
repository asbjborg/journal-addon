const fs = require('fs').promises;
const path = require('path');

/**
 * Read session JSONL file from path built from config.
 * Input: { path_to_sessions, realm, character_name, session } (config)
 * Params: optional overrides for same keys
 * Output: { config, content } (content = file as string)
 */
async function run(input, params = {}) {
  const config = { ...input, ...params };
  const { path_to_sessions, realm, character_name, session } = config;
  if (!path_to_sessions || !realm || !character_name || !session) {
    throw new Error('read-file: missing path_to_sessions, realm, character_name, or session');
  }
  const filePath = path.join(
    path_to_sessions,
    realm,
    character_name,
    `session-${session}`,
    `session-${session}.jsonl`
  );
  const content = await fs.readFile(filePath, 'utf8');
  return { config, content };
}

module.exports = { run };
