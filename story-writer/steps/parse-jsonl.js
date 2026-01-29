/**
 * Parse JSONL string into array of events.
 * Input: { content } (from read-file)
 * Output: { config, events }
 */
function run(input, _params) {
  const { config, content } = input;
  if (content == null) throw new Error('parse-jsonl: missing content');
  const events = [];
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      events.push(JSON.parse(trimmed));
    } catch (_) {}
  }
  return { config, events };
}

module.exports = { run };
