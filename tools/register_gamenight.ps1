param([string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'GameNight'))
$ErrorActionPreference = 'Stop'
$goalRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$goalBinary = (Resolve-Path -LiteralPath (Join-Path $goalRoot 'build/GoalRush.exe')).Path
$goalLocalFile = Join-Path $DataDirectory 'local-games.json'
New-Item -ItemType Directory -Force -Path $DataDirectory | Out-Null
$goalEntries = @()
if (Test-Path -LiteralPath $goalLocalFile) {
    Copy-Item -LiteralPath $goalLocalFile -Destination (Join-Path $goalRoot 'build/local-games-before-goal-rush.json')
    $goalEntries = @(Get-Content -LiteralPath $goalLocalFile -Raw | ConvertFrom-Json | Where-Object { $_.id -notin @('goal-rush', 'goal-rush-2v2', 'goal-rush-3v3') })
}
foreach ($goalTeamSize in 1..3) {
$goalMode = "${goalTeamSize}v${goalTeamSize}"
$goalEntries += [ordered]@{
    id=$(if ($goalTeamSize -eq 1) { 'goal-rush' } else { "goal-rush-$goalMode" })
    title="Goal Rush $goalMode (Local)"; tagline=$(if ($goalTeamSize -eq 1) { 'Two units per controller. Left stick + LB / right stick + RB.' } else { "$goalMode football. One unit per controller. Bots fill empty places." })
    color='#ff7547'; emoji='⚽'; players="1-$($goalTeamSize * 2) players"; min_players=1; max_players=($goalTeamSize * 2); best_players=($goalTeamSize * 2)
    screenshot=(Join-Path $goalRoot 'assets/gameplay.png')
    cover=(Join-Path $goalRoot 'assets/gameplay.png')
    icon=(Join-Path $goalRoot 'assets/icon.png')
    launch=@{command=$goalBinary; args=@('--position','-30000,-30000','--',"--teams=$goalTeamSize"); cwd=(Join-Path $goalRoot 'build')}
}
}
[System.IO.File]::WriteAllText($goalLocalFile,(ConvertTo-Json -InputObject @($goalEntries) -Depth 12),(New-Object System.Text.UTF8Encoding $false))
Write-Output "Registered Goal Rush in $goalLocalFile"
