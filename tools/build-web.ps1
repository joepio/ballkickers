# Godot 4.5.2 with the Web release export template installed.
param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$build = Join-Path $root 'build'
$output = Join-Path $build 'web'
$licenses = Join-Path $output 'licenses'
New-Item -ItemType Directory -Path $licenses -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $build '.gdignore') -Force | Out-Null

& $Godot --headless --path $root --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $Godot --headless --path $root --export-release Web (Join-Path $output 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'Godot Web export failed' }

Copy-Item -LiteralPath (Join-Path $root 'addons/gamenight/browser_transport.js') -Destination (Join-Path $output 'bridge.js')
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $licenses 'Ballkickers-LICENSE.txt')
Get-ChildItem -LiteralPath (Join-Path $root 'third_party') -Filter '*.txt' -File | Copy-Item -Destination $licenses
Copy-Item -LiteralPath (Join-Path $root 'addons/crowd_sound/samples/CREDITS.md') -Destination (Join-Path $licenses 'Crowd-samples-CREDITS.txt')
Copy-Item -LiteralPath (Join-Path $root 'tools/audio_sources/KENNEY-LICENSE.txt') -Destination $licenses

$links = Get-ChildItem -Path $licenses -Filter '*.txt' -File | Sort-Object Name | ForEach-Object {
    $label = [Net.WebUtility]::HtmlEncode($_.Name)
    $href = [Uri]::EscapeDataString($_.Name)
    "<li><a href='$href'>$label</a></li>"
}
$credits = '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Ballkickers credits and licenses</title><h1>Ballkickers credits and licenses</h1><ul>' + ($links -join [Environment]::NewLine) + '</ul></html>'
[IO.File]::WriteAllText((Join-Path $licenses 'index.html'), $credits, [Text.UTF8Encoding]::new($false))
Write-Output "Web build ready at $output"
