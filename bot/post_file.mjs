// Posts a text file to the Telegram channel as a monospace block.
//
// Usage (PowerShell):
//   $env:TELEGRAM_BOT_TOKEN = Read-Host "Paste token"
//   $env:TELEGRAM_CHAT_ID   = "-1001738283594"
//   node bot/post_file.mjs                      # sends bot/todays_pick.txt
//   node bot/post_file.mjs path\to\file.txt
//   node bot/post_file.mjs --raw                # no ``` wrapper
//   node bot/post_file.mjs --dry-run            # print only, send nothing
//
// Exit code 0 = Telegram accepted the message.

import fs from 'fs';
import path from 'path';

const args = process.argv.slice(2);
const RAW = args.includes('--raw');
const DRY = args.includes('--dry-run');
const fileArg = args.find(a => !a.startsWith('--'));

const filePath = path.resolve(fileArg || 'bot/todays_pick.txt');

if (!fs.existsSync(filePath)) {
  console.error(`✗ File not found: ${filePath}`);
  process.exit(1);
}

const text = fs.readFileSync(filePath, 'utf8').replace(/\r\n/g, '\n').trimEnd();
if (!text) {
  console.error(`✗ File is empty: ${filePath}`);
  process.exit(1);
}

const payload = RAW ? text : '```\n' + text + '\n```';

if (DRY) {
  console.log(payload);
  process.exit(0);
}

const TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const CHAT = process.env.TELEGRAM_CHAT_ID;

if (!TOKEN) {
  console.error('✗ TELEGRAM_BOT_TOKEN is not set in this shell.');
  process.exit(1);
}
if (!CHAT) {
  console.error('✗ TELEGRAM_CHAT_ID is not set in this shell.');
  process.exit(1);
}

const url = `https://api.telegram.org/bot${TOKEN}/sendMessage`;
const send = body =>
  fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: CHAT, disable_web_page_preview: true, ...body }),
  }).then(async r => ({ status: r.status, json: await r.json().catch(() => null) }));

const first = await send({ text: payload, parse_mode: 'Markdown' });

if (first.json?.ok) {
  console.log(`✓ Posted ${path.basename(filePath)} to ${CHAT} (message ${first.json.result.message_id}).`);
  process.exit(0);
}

console.warn(`Markdown send failed (${first.json?.error_code}: ${first.json?.description}) — retrying as plain text.`);

const retry = await send({ text: payload.replace(/^```\n?|\n?```$/g, '') });

if (retry.json?.ok) {
  console.log(`✓ Posted ${path.basename(filePath)} as plain text (message ${retry.json.result.message_id}).`);
  process.exit(0);
}

console.error(`✗ Telegram rejected it: ${retry.json?.error_code} ${retry.json?.description || retry.status}`);
process.exit(1);
