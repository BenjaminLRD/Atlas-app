# Builds the release APK with the project's settings and checks the result.
#
#   powershell -File tool/build_release_apk.ps1
#
# It runs: flutter build apk --release --no-pub --dart-define-from-file=.env
# Before building it checks .env has SUPABASE_URL and SUPABASE_ANON_KEY, and
# after building it checks the arm64 app really contains the project host and
# not only the placeholder. It never prints a key or the full URL.
# Add -SplitPerAbi for one APK per CPU (the arm64 one is for modern phones).
param([switch]$SplitPerAbi)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path .env)) { throw '.env is missing. It must define SUPABASE_URL and SUPABASE_ANON_KEY.' }
$vars = @{}
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$') { $vars[$Matches[1]] = $Matches[2] }
}
foreach ($name in 'SUPABASE_URL', 'SUPABASE_ANON_KEY') {
  if (-not $vars.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($vars[$name])) {
    throw "$name is missing or empty in .env"
  }
}
if ($vars['SUPABASE_URL'] -notmatch '^https?://') { throw 'SUPABASE_URL in .env is not an http(s) address.' }
if ($vars['SUPABASE_ANON_KEY'].Length -le 20) { throw 'SUPABASE_ANON_KEY in .env looks too short.' }
Write-Host 'Settings present: SUPABASE_URL, SUPABASE_ANON_KEY (values not shown).'

$args = @('build', 'apk', '--release', '--no-pub', '--dart-define-from-file=.env')
if ($SplitPerAbi) { $args += '--split-per-abi' }
& flutter @args
if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }

$apkDir = 'build\app\outputs\flutter-apk'
$apk = if ($SplitPerAbi) { "$apkDir\app-arm64-v8a-release.apk" } else { "$apkDir\app-release.apk" }
if (-not (Test-Path $apk)) { throw "Expected $apk was not produced." }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $apk))
try {
  $entry = $zip.Entries | Where-Object { $_.FullName -like 'lib/*/libapp.so' } | Select-Object -First 1
  $ms = New-Object IO.MemoryStream
  $st = $entry.Open(); $st.CopyTo($ms); $st.Close()
  $text = [Text.Encoding]::GetEncoding(28591).GetString($ms.ToArray())
} finally { $zip.Dispose() }

$hostName = ([Uri]$vars['SUPABASE_URL']).Host
if ($text.Contains($hostName)) { Write-Host 'OK: the APK contains the Supabase project address.' }
else { throw 'The APK does NOT contain the Supabase project address.' }
if ($text.Contains($vars['SUPABASE_ANON_KEY'])) { Write-Host 'OK: the APK contains the anon key.' }
else { throw 'The APK does NOT contain the anon key.' }
Write-Host "Built $apk"
