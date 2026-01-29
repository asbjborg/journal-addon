const path = require('path');
const fs = require('fs');
const { run, readFile, parseJsonl, collectQuestIds, fetchWowheadQuests, enrichJsonl } = require('../../steps/index.js');
const { defaultConfig } = require('./config.js');

function loadEnv(envPath) {
  try {
    const content = fs.readFileSync(envPath, 'utf8');
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      const key = trimmed.slice(0, eq).trim();
      let val = trimmed.slice(eq + 1).trim();
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'")))
        val = val.slice(1, -1);
      process.env[key] = val;
    }
  } catch (_) {}
}

// Load .env from workflow directory or cwd (only sets vars that are not already set)
const envFile = path.join(__dirname, '.env');
if (fs.existsSync(envFile)) loadEnv(envFile);
else {
  const cwdEnv = path.join(process.cwd(), '.env');
  if (fs.existsSync(cwdEnv)) loadEnv(cwdEnv);
}

async function main() {
  const config = {
    ...defaultConfig,
    path_to_sessions: process.env.PATH_TO_SESSIONS || defaultConfig.path_to_sessions,
    realm: process.env.REALM || defaultConfig.realm,
    character_name: process.env.CHARACTER_NAME || defaultConfig.character_name,
    session: process.env.SESSION || defaultConfig.session,
  };

  const pipeline = [
    { step: readFile, params: config },
    { step: parseJsonl },
    { step: collectQuestIds },
    { step: fetchWowheadQuests, params: { baseUrl: 'https://www.wowhead.com/tbc/quest=' } },
    { step: enrichJsonl },
  ];

  const result = await run(pipeline, config);
  for (const event of result.events) {
    console.log(JSON.stringify(event));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
