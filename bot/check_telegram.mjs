// Telegram credential checker — verifies the same env vars scrape.yml passes
// to scraper.mjs. Read-only: it never sends a message unless you pass --send.
//
// Usage (PowerShell):
//   $env:TELEGRAM_BOT_TOKEN="123:ABC..."
//   $env:TELEGRAM_CHAT_ID="-1001738283594"
//   node bot/check_telegram.mjs
//   node bot/check_telegram.mjs --send     # also posts one test line
//
// Exit code 0 = everything the scraper needs is working.

const TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const CHAT = process.env.TELEGRAM_CHAT_ID;
const SEND = process.argv.includes('--send');

const api = (method, params = {}) =>
  fetch(`https://api.telegram.org/bot${TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(params),
  }).then(async r => ({ ok: r.ok, status: r.status, json: await r.json().catch(() => null) }));

function fail(msg) {
  console.error(`✗ ${msg}`);
  process.exit(1);
}

if (!TOKEN) fail('TELEGRAM_BOT_TOKEN is not set in this shell.');
if (!CHAT) fail('TELEGRAM_CHAT_ID is not set in this shell.');

console.log(`Token:    ...${TOKEN.slice(-6)} (${TOKEN.length} chars)`);
console.log(`Chat ID:  ${CHAT}\n`);

// 1. Token valid?
const me = await api('getMe');
if (!me.ok || !me.json?.ok) {
  fail(`getMe failed: ${me.json?.description || me.status} — the bot token is invalid or revoked.`);
}
const bot = me.json.result;
console.log(`✓ Token valid — @${bot.username} (id ${bot.id})`);

// 2. Chat reachable?
const chat = await api('getChat', { chat_id: CHAT });
if (!chat.ok || !chat.json?.ok) {
  fail(
    `getChat failed: ${chat.json?.description || chat.status}\n` +
    `  → wrong chat ID, or the bot was never added to that chat.`
  );
}
console.log(`✓ Chat found — "${chat.json.result.title || chat.json.result.username}" (${chat.json.result.type})`);

// 3. Can it post? (groups/channels need the bot present; channels need admin)
const member = await api('getChatMember', { chat_id: CHAT, user_id: bot.id });
const status = member.json?.result?.status;
if (!member.ok || !status) {
  fail(`getChatMember failed: ${member.json?.description || member.status}`);
}
const canPost = ['creator', 'administrator', 'member'].includes(status);
console.log(`${canPost ? '✓' : '✗'} Bot status in chat: ${status}${canPost ? '' : ' — it cannot send messages'}`);
if (!canPost) process.exit(1);

if (SEND) {
  const msg = await api('sendMessage', {
    chat_id: CHAT,
    text: '✅ Test message from check_telegram.mjs — scraper credentials are working.',
    disable_web_page_preview: true,
  });
  if (!msg.ok || !msg.json?.ok) {
    fail(`sendMessage failed: ${msg.json?.description || msg.status}`);
  }
  console.log('✓ Test message delivered — check the channel.');
} else {
  console.log('\nAll checks passed. Re-run with --send to post a real test message.');
}
