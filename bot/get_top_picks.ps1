$res = Invoke-RestMethod -Uri 'https://ai-football-bot.xantechs00.workers.dev'
$matches = $res.matchesData.matches
if (-not $matches) { $matches = $res.matches }

$upcoming = $matches | Where-Object { $_.status -ne 'finished' -and $_.status -ne 'FT' }

foreach ($m in $upcoming) {
    $rec = $m.prediction.recommendation
    $hp = [int]($m.prediction.homeWinProbability)
    $ap = [int]($m.prediction.awayWinProbability)
    $dp = [int]($m.prediction.drawProbability)
    $prob = [Math]::Max($hp, [Math]::Max($ap, $dp))
    
    if ($prob -ge 55) {
        Write-Output ("TOP PICK: " + $m.homeTeam + " vs " + $m.awayTeam + " (" + $m.league + ") | Time: " + $m.date + " | Pick: " + $rec + " (" + $prob + "%)")
    }
}
