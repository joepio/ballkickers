param([string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'GameNight'))
$ErrorActionPreference = 'Stop'
$goalRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$goalBinary = (Resolve-Path -LiteralPath (Join-Path $goalRoot 'build/Ballkickers.exe')).Path
$goalLocalFile = Join-Path $DataDirectory 'local-games.json'
New-Item -ItemType Directory -Force -Path $DataDirectory | Out-Null
$goalEntries = @()
if (Test-Path -LiteralPath $goalLocalFile) {
    Copy-Item -LiteralPath $goalLocalFile -Destination (Join-Path $goalRoot 'build/local-games-before-ballkickers.json')
    $goalEntries = @(Get-Content -LiteralPath $goalLocalFile -Raw | ConvertFrom-Json | Where-Object { $_.id -notin @('ballkickers', 'ballkickers-2v2', 'ballkickers-3v3', 'goal-rush', 'goal-rush-2v2', 'goal-rush-3v3') })
}
$goalEntries += [ordered]@{
    id='ballkickers'
    title='Ballkickers'; tagline='Fast party football. Teams adapt to your party; bots fill empty places.'
    color='#ff7547'; emoji='⚽'; players='1-6 players'; min_players=1; max_players=6; best_players=4
    screenshot=(Join-Path $goalRoot 'assets/gameplay.png')
    cover=(Join-Path $goalRoot 'assets/cover.png')
    icon=(Join-Path $goalRoot 'assets/icon.png')
    launch=@{command=$goalBinary; args=@('--position','-30000,-30000'); cwd=(Join-Path $goalRoot 'build')}
}
[System.IO.File]::WriteAllText($goalLocalFile,(ConvertTo-Json -InputObject @($goalEntries) -Depth 12),(New-Object System.Text.UTF8Encoding $false))
Write-Output "Registered Ballkickers in $goalLocalFile"
