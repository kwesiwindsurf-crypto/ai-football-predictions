$url = 'https://t.me/s/ai_scorecast_football'
$html = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
$matches = [regex]::Matches($html, '(?s)<div class="tgme_widget_message_text[^"]*"[^>]*>(.*?)</div>')
Write-Output ("Found " + $matches.Count + " messages")

if ($matches.Count -gt 0) {
    $last = $matches[$matches.Count - 1]
    Write-Output "=== LAST MESSAGE ==="
    $cleanText = $last.Groups[1].Value -replace '<br/>', "`n" -replace '<[^>]+>', ''
    Write-Output $cleanText
}
