$historyPath = "docs/data/history.json"
$staticHistory = @()
if (Test-Path $historyPath) {
    $staticHistory = Get-Content $historyPath -Raw | ConvertFrom-Json
}

$workerData = $null
$step28Path = "C:\Users\alexa\.gemini\antigravity-ide\brain\27dbef2d-f091-41b5-b2e3-f0e39f40b1d0\.system_generated\steps\28\content.md"
if (Test-Path $step28Path) {
    $rawText = Get-Content $step28Path -Raw
    $idx = $rawText.IndexOf("{")
    if ($idx -ge 0) {
        $jsonStr = $rawText.Substring($idx)
        $workerData = $jsonStr | ConvertFrom-Json
        Write-Host "Successfully loaded worker data from cached snapshot!"
    }
}

$rollingMatches = @()
if ($workerData) {
    if ($workerData.matchesData -and $workerData.matchesData.matches) {
        $rollingMatches = $workerData.matchesData.matches
    } elseif ($workerData.matches) {
        $rollingMatches = $workerData.matches
    }
}
$historicalMatches = @()
if ($workerData -and $workerData.historicalMatches) {
    $historicalMatches = $workerData.historicalMatches
}

$matchMap = @{}
foreach ($m in ($staticHistory + $historicalMatches)) {
    if ($m -and $m.id) { $matchMap[$m.id] = $m }
}
foreach ($m in $rollingMatches) {
    if ($m -and $m.id) { $matchMap[$m.id] = $m }
}

function Evaluate-Prediction($rec, $hScore, $aScore, $hTeam, $aTeam) {
    $h = [int]$hScore
    $a = [int]$aScore
    $total = $h + $a
    $isDraw = ($h -eq $a)
    $recStr = "$rec"

    $result = "UNKNOWN"

    if ($recStr -match 'to Win \(1\)') {
        if ($h -gt $a) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'to Win \(2\)') {
        if ($a -gt $h) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'or Draw|Double Chance|1X|X2') {
        $isHome = ($recStr -match [regex]::Escape($hTeam)) -or ($recStr -match '1X')
        $isAway = ($recStr -match [regex]::Escape($aTeam)) -or ($recStr -match 'X2')
        if ($isHome -and -not $isAway) {
            if ($h -ge $a) { $result = "WON" } else { $result = "LOST" }
        } elseif ($isAway -and -not $isHome) {
            if ($a -ge $h) { $result = "WON" } else { $result = "LOST" }
        } elseif ($recStr -match '12') {
            if ($h -ne $a) { $result = "WON" } else { $result = "LOST" }
        }
    } elseif ($recStr -match 'Over 0\.5') {
        if ($total -ge 1) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'Over 1\.5') {
        if ($total -ge 2) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'Over 2\.5') {
        if ($total -ge 3) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'Over 3\.5') {
        if ($total -ge 4) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'Under 1\.5') {
        if ($total -lt 2) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'Under 2\.5') {
        if ($total -lt 3) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'Under 3\.5') {
        if ($total -lt 4) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match 'Both Teams To Score|BTTS') {
        if ($h -gt 0 -and $a -gt 0) { $result = "WON" } else { $result = "LOST" }
    } elseif ($recStr -match '(?i)draw') {
        if ($h -eq $a) { $result = "WON" } else { $result = "LOST" }
    }

    return @{ Result = $result; IsDraw = $isDraw }
}

$allEvaluated = @()
foreach ($m in $matchMap.Values) {
    $isFT = ($m.status -eq 'finished' -or $m.statusShort -eq 'FT')
    $res = "PENDING"
    $isDraw = $false
    if ($isFT -and $null -ne $m.homeScore -and $null -ne $m.awayScore) {
        $eval = Evaluate-Prediction $m.prediction.recommendation $m.homeScore $m.awayScore $m.homeTeam $m.awayTeam
        $res = $eval.Result
        $isDraw = $eval.IsDraw
    }
    $allEvaluated += [PSCustomObject]@{
        Match = $m
        Result = $res
        IsDraw = $isDraw
    }
}

$won = $allEvaluated | Where-Object { $_.Result -eq 'WON' }
$lost = $allEvaluated | Where-Object { $_.Result -eq 'LOST' }
$pending = $allEvaluated | Where-Object { $_.Result -eq 'PENDING' }

Write-Host "Total: $($allEvaluated.Count), Won: $($won.Count), Lost: $($lost.Count), Pending: $($pending.Count)"

Write-Host "`n=== BREAKDOWN OF LOSSES BY RECOMMENDATION ==="
$lost | Group-Object { $_.Match.prediction.recommendation } | Select-Object Name, Count | Format-Table -AutoSize

Write-Host "`n=== BREAKDOWN OF LOSSES BY SCORELINE ==="
$lost | Group-Object { "$($_.Match.homeScore)-$($_.Match.awayScore)" } | Select-Object Name, Count | Format-Table -AutoSize

Write-Host "`n=== BREAKDOWN OF LOSSES BY LEAGUE ==="
$lost | Group-Object { $_.Match.league } | Select-Object Name, Count | Format-Table -AutoSize

Write-Host "`n=== DETAILED LIST OF 35 LOSSES ==="
$i = 1
foreach ($l in $lost) {
    $m = $l.Match
    $rec = $m.prediction.recommendation
    $tot = [int]$m.homeScore + [int]$m.awayScore
    $analysis = $m.prediction.analysis -replace "`n", " "
    Write-Host "$i. [$($m.league)] $($m.homeTeam) $($m.homeScore)-$($m.awayScore) $($m.awayTeam) | Rec: '$rec' | TotalGoals: $tot | Probs: H:$($m.prediction.homeWinProbability)% D:$($m.prediction.drawProbability)% A:$($m.prediction.awayWinProbability)% | OddsRating: $($m.oddsRating)"
    Write-Host "   Analysis: $analysis"
    $i++
}
