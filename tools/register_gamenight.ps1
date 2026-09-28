param([string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'GameNight'))
$ErrorActionPreference = 'Stop'
$goalRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$goalBinary = (Resolve-Path -LiteralPath (Join-Path $goalRoot 'build/GoalRush.exe')).Path
$goalLocalFile = Join-Path $DataDirectory 'local-games.json'
New-Item -ItemType Directory -Force -Path $DataDirectory | Out-Null
$goalEntries = @()
if (Test-Path -LiteralPath $goalLocalFile) {
    Copy-Item -LiteralPath $goalLocalFile -Destination (Join-Path $goalRoot 'build/local-games-before-goal-rush.json')
    $goalEntries = @(Get-Content -LiteralPath $goalLocalFile -Raw | ConvertFrom-Json | Where-Object { $_.id -ne 'goal-rush' })
}
$goalEntries += [ordered]@{
    id='goal-rush'; title='Goal Rush (Local)'; tagline='2v2 football: one controller, two players. With diving keepers.'
    color='#ff7547'; emoji='⚽'; players='1-2 players'; min_players=1; max_players=2; best_players=2
    screenshot=(Join-Path $goalRoot 'assets/gameplay.png')
    cover=(Join-Path $goalRoot 'assets/gameplay.png')
    icon=(Join-Path $goalRoot 'assets/icon.png')
    launch=@{command=$goalBinary; args=@('--position','-30000,-30000'); cwd=(Join-Path $goalRoot 'build')}
}
[System.IO.File]::WriteAllText($goalLocalFile,(ConvertTo-Json -InputObject @($goalEntries) -Depth 12),(New-Object System.Text.UTF8Encoding $false))
Write-Output "Registered Goal Rush in $goalLocalFile"
