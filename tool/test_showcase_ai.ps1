# Checks the deployed ai-proxy Showcase pathway end to end, from this machine.
# Run it AFTER you deploy the function and set SHOWCASE_AI_ENABLED=true.
# It reads the Supabase URL and anon key from .env, never prints them, and
# prints only the HTTP status and the first words of the reply.
#
#   powershell -NoProfile -File tool/test_showcase_ai.ps1
param([string]$EnvFile = (Join-Path $PSScriptRoot '..\.env'))

$vars = @{}
Get-Content $EnvFile | ForEach-Object {
  if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$') { $vars[$Matches[1]] = $Matches[2].Trim('"') }
}
$url = $vars['SUPABASE_URL']; $anon = $vars['SUPABASE_ANON_KEY']
if (-not $url -or -not $anon) { throw 'SUPABASE_URL / SUPABASE_ANON_KEY not found in .env' }
$endpoint = ($url.TrimEnd('/')) + '/functions/v1/ai-proxy'

function Send($label, $headers, $body) {
  try {
    $r = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -Body $body -ContentType 'application/json' -UseBasicParsing
    $code = [int]$r.StatusCode; $text = $r.Content
  } catch {
    $code = [int]$_.Exception.Response.StatusCode
    $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream()); $text = $sr.ReadToEnd()
  }
  $short = if ($text.Length -gt 110) { $text.Substring(0, 110) + '...' } else { $text }
  '{0,-34} HTTP {1}  {2}' -f $label, $code, ($short -replace '\s+', ' ')
}

$ok = @{ 'Authorization' = "Bearer $anon"; 'apikey' = $anon; 'x-atlas-showcase' = '1' }
$req = @{ model = 'gemini-2.5-flash'; feature = 'coach'; showcase = $true
  request = @{ contents = @(@{ role = 'user'; parts = @(@{ text = 'Reply with the single word: ready' }) }) } } | ConvertTo-Json -Depth 8

Send '1 showcase coach (expect 200)' $ok $req
Send '2 wrong bearer (expect 401)' @{ 'Authorization' = 'Bearer not-the-anon-key'; 'apikey' = $anon; 'x-atlas-showcase' = '1' } $req
$bad = $req -replace 'gemini-2.5-flash', 'gemini-other'
Send '3 disallowed model (expect 400)' $ok $bad
# Signed-in path must still demand a user token: the anon key without the
# showcase header is not a user session.
Send '4 no showcase header (expect 401)' @{ 'Authorization' = "Bearer $anon"; 'apikey' = $anon } $req

# Request validation (the server rebuilds the request; these must be refused).
$badRole = $req -replace '"role":\s*"user"', '"role": "function"'
Send '5 unsupported role (expect 400)' $ok $badRole
$huge = @{ model = 'gemini-2.5-flash'; feature = 'coach'; showcase = $true
  request = @{ contents = @(@{ role = 'user'; parts = @(@{ text = ('a' * 70000) }) }) } } | ConvertTo-Json -Depth 8
Send '6 over-long text (expect 400/413)' $ok $huge
$extra = @{ model = 'gemini-2.5-flash'; feature = 'coach'; showcase = $true
  request = @{ contents = @(@{ role = 'user'; parts = @(@{ text = 'Reply with the single word: ready' }) })
    tools = @(@{ googleSearch = @{} }); safetySettings = @(@{ category = 'HARM_CATEGORY_DANGEROUS_CONTENT'; threshold = 'BLOCK_NONE' })
    generationConfig = @{ candidateCount = 8; maxOutputTokens = 999999 } } } | ConvertTo-Json -Depth 8
Send '7 injected config (expect 200, ignored)' $ok $extra
