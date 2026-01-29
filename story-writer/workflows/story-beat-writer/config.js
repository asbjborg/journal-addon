const path = require('path');

/**
 * Default config for story-beat-writer workflow.
 * Override via env: PATH_TO_SESSIONS, REALM, CHARACTER_NAME, SESSION.
 * Default path points to workflow examples so it runs without real sessions.
 */
const defaultConfig = {
  path_to_sessions: path.join(__dirname, 'examples'),
  realm: 'Thunderstrike',
  character_name: 'Maskine',
  session: '01',
};

module.exports = { defaultConfig };
