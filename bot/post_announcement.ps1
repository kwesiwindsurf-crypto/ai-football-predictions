$token = $env:TELEGRAM_BOT_TOKEN
$chatId = $env:TELEGRAM_CHAT_ID
if (-not $token -or -not $chatId) { throw "Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID env vars first" }
$url = "https://api.telegram.org/bot$token/sendMessage"

$message = @"
🎯 <b>AI SCORECAST: FEATURED PICKS & UPCOMING MATCHES</b> 🎯

⭐ <b>TOP BANKER PICKS:</b>

• <b>Al Hilal vs Al Hazem</b> (Saudi Pro League)
  💡 <b>Pick:</b> Al Hilal to Win (1) [76% Probability]
  🛡️ <b>Safe Cover:</b> 1X (Al Hilal or Draw)

• <b>Al Fayha vs Al Ahli</b> (Saudi Pro League)
  💡 <b>Pick:</b> Al Ahli to Win (2) [66% Probability]
  🛡️ <b>Safe Cover:</b> X2 (Al Ahli or Draw)

• <b>Tottenham Hotspur vs Coventry City</b> (Premier League)
  💡 <b>Pick:</b> Over 1.5 Goals
  🛡️ <b>Safe Cover:</b> Over 1.5 Goals

• <b>Fenerbahce vs Slavia Prague</b> (UEFA Champions League)
  💡 <b>Pick:</b> Fenerbahce to Win (1) [72% Probability]
  🛡️ <b>Safe Cover:</b> 1X (Fenerbahce or Draw)

• <b>Real Madrid vs RB Leipzig</b> (UEFA Champions League)
  💡 <b>Pick:</b> Real Madrid to Win (1) [68% Probability]
  🛡️ <b>Safe Cover:</b> 1X (Real Madrid or Draw)

────────────────────
📊 <b>Full Match Details, Live Scores & 350+ Predictions:</b>
👉 <a href="https://kwesiwindsurf-crypto.github.io/ai-football-predictions/">Open Live Analytics Dashboard</a>
"@

$payload = @{
    chat_id = $chatId
    text = $message
    parse_mode = "HTML"
    disable_web_page_preview = $true
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $url -Method Post -Body $payload -ContentType "application/json; charset=utf-8"
Write-Output ("Message Sent Successfully: " + $response.ok)
Write-Output ("Message ID: " + $response.result.message_id)
