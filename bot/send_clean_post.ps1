$target = [char]::ConvertFromUtf32(0x1F3AF)
$star = [char]::ConvertFromUtf32(0x2B50)
$ball = [char]::ConvertFromUtf32(0x26BD)
$bulb = [char]::ConvertFromUtf32(0x1F4A1)
$shield = [char]::ConvertFromUtf32(0x1F6E1)
$chart = [char]::ConvertFromUtf32(0x1F4CA)
$hand = [char]::ConvertFromUtf32(0x1F449)

$token = $env:TELEGRAM_BOT_TOKEN
$chatId = $env:TELEGRAM_CHAT_ID
if (-not $token -or -not $chatId) { throw "Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID env vars first" }
$url = "https://api.telegram.org/bot$token/sendMessage"

$lines = @(
    "$target <b>AI SCORECAST: FEATURED PICKS & FIXTURES</b> $target",
    "",
    "$star <b>TOP BANKER PICKS:</b>",
    "",
    "$ball <b>Al Hilal vs Al Hazem</b> (Saudi Pro League)",
    "  $bulb <b>Pick:</b> Al Hilal to Win (1) [76% Prob]",
    "  $shield <b>Safe:</b> 1X (Al Hilal or Draw)",
    "",
    "$ball <b>Tottenham Hotspur vs Coventry City</b> (Premier League)",
    "  $bulb <b>Pick:</b> Over 1.5 Goals",
    "  $shield <b>Safe:</b> Over 1.5 Goals",
    "",
    "$ball <b>Fenerbahce vs Slavia Prague</b> (UEFA Champions League)",
    "  $bulb <b>Pick:</b> Fenerbahce to Win (1) [72% Prob]",
    "  $shield <b>Safe:</b> 1X (Fenerbahce or Draw)",
    "",
    "$ball <b>Real Madrid vs RB Leipzig</b> (UEFA Champions League)",
    "  $bulb <b>Pick:</b> Real Madrid to Win (1) [68% Prob]",
    "  $shield <b>Safe:</b> 1X (Real Madrid or Draw)",
    "",
    "$ball <b>Al Fayha vs Al Ahli</b> (Saudi Pro League)",
    "  $bulb <b>Pick:</b> Al Ahli to Win (2) [66% Prob]",
    "  $shield <b>Safe:</b> X2 (Al Ahli or Draw)",
    "",
    "----------------------------------------",
    "$chart <b>Full Match Details, Live Scores & 350+ Predictions:</b>",
    "$hand <a href=""https://kwesiwindsurf-crypto.github.io/ai-football-predictions/"">Open Live Analytics Dashboard</a>"
)

$text = $lines -join "`n"

$payloadObj = @{
    chat_id = $chatId
    text = $text
    parse_mode = "HTML"
    disable_web_page_preview = $true
}

$json = $payloadObj | ConvertTo-Json -Compress
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

$res = Invoke-RestMethod -Uri $url -Method Post -Body $bytes -ContentType "application/json; charset=utf-8"
Write-Output ("Message Sent Successfully: " + $res.ok)
Write-Output ("New Message ID: " + $res.result.message_id)
