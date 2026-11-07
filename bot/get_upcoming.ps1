$res = Invoke-RestMethod -Uri 'https://ai-football-bot.xantechs00.workers.dev'
$matches = $res.matchesData.matches
if (-not $matches) { $matches = $res.matches }
Write-Output ("Total matches in KV: " + $matches.Count)

$upcoming = $matches | Where-Object { $_.status -ne 'finished' -and $_.status -ne 'FT' }
Write-Output ("Found upcoming: " + $upcoming.Count)

$upcoming | Select-Object -First 10 | ForEach-Object {
    $p = $_.prediction
    $maxP = [Math]::Max($p.homeWinProbability, [Math]::Max($p.drawProbability, $p.awayWinProbability))
    Write-Output ($_.homeTeam + " vs " + $_.awayTeam + " (" + $_.league + ") | Time: " + $_.date + " | Pick: " + $p.recommendation + " (" + $maxP + "%)")
}
