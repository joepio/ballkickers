param([string]$Godot = 'C:/dev/tools/godot/Godot_v4.5.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$goalRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
$goalOutput = Join-Path $goalRoot 'build'
New-Item -ItemType Directory -Force -Path $goalOutput | Out-Null
& $Godot --headless --path $goalRoot --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $Godot --headless --path $goalRoot --script res://tests/settings.gd
if ($LASTEXITCODE -ne 0) { throw 'Settings checks failed' }
& $Godot --headless --path $goalRoot --script res://tests/simulation.gd
if ($LASTEXITCODE -ne 0) { throw 'Simulation checks failed' }
& $Godot --headless --path $goalRoot --script res://tests/input_lifecycle.gd
if ($LASTEXITCODE -ne 0) { throw 'Input/lifecycle checks failed' }
& $Godot --headless --path $goalRoot --script res://tests/modes_keepers.gd
if ($LASTEXITCODE -ne 0) { throw 'Modes/keeper checks failed' }
& $Godot --headless --path $goalRoot --script res://tests/chaos.gd
if ($LASTEXITCODE -ne 0) { throw 'Chaos checks failed' }
& $Godot --headless --path $goalRoot --script res://tests/replay.gd
if ($LASTEXITCODE -ne 0) { throw 'Replay checks failed' }
& $Godot --headless --path $goalRoot --script res://tests/audio.gd
if ($LASTEXITCODE -ne 0) { throw 'Audio checks failed' }
& $Godot --headless --path $goalRoot --script res://tests/crowd.gd
if ($LASTEXITCODE -ne 0) { throw 'Crowd checks failed' }
& $Godot --headless --path $goalRoot --export-pack 'Windows Desktop' (Join-Path $goalOutput 'Ballkickers.pck')
if ($LASTEXITCODE -ne 0) { throw 'Pack export failed' }
# The installed editor can run a same-named PCK without export templates.
$goalEngine = $Godot.Replace('_console.exe', '.exe')
Copy-Item -LiteralPath $goalEngine -Destination (Join-Path $goalOutput 'Ballkickers.exe')
Copy-Item -LiteralPath (Join-Path $goalRoot 'README.md') -Destination $goalOutput
Copy-Item -LiteralPath (Join-Path $goalRoot 'LICENSE') -Destination $goalOutput
New-Item -ItemType Directory -Force -Path (Join-Path $goalOutput 'licenses') | Out-Null
Copy-Item -Path (Join-Path $goalRoot 'third_party/*.txt') -Destination (Join-Path $goalOutput 'licenses')
Write-Output "Ready: $goalOutput/Ballkickers.exe"
