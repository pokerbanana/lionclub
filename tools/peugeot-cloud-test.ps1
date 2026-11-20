<#
.SYNOPSIS
  One-off check: does Peugeot's cloud have live data for your car?

.DESCRIPTION
  LionClub can only show what Peugeot's servers know about your car. MyPeugeot can also get
  data over Bluetooth from the car to the phone, which a self-built app can't use. This script
  asks Peugeot's servers directly, so we know which version of the app to build.

  1. Peugeot's own login page opens in your browser. You type your password there, never here.
  2. You paste back the one-time code the browser shows after signing in.
  3. The script trades it for a temporary token and reads your cars and their status.

  Only a short summary is printed. Nothing is saved unless you add -SaveSample.

.PARAMETER Country
  Country code of your MyPeugeot account. Default: HR (Croatia).

.PARAMETER SaveSample
  Also save each car's status to tools\status-sample-N.json with the VIN, ids, links and GPS
  position removed, to use as test data for the app.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\peugeot-cloud-test.ps1
#>
param(
    [string]$Country = 'HR',
    [switch]$SaveSample
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$api = 'https://api.groupe-psa.com'
$sensitive = @('vin', 'id', 'coordinates', 'customer', 'customerId', 'href', 'pictures')

function Get-HttpStatus($err) {
    $resp = $err.Exception.Response
    if ($null -ne $resp) { return [int]$resp.StatusCode }
    return 0
}

function Format-Age([TimeSpan]$age) {
    if ($age.TotalMinutes -lt 90) { return ('{0:N0} min ago' -f $age.TotalMinutes) }
    if ($age.TotalHours -lt 48) { return ('{0:N0} h ago' -f $age.TotalHours) }
    return ('{0:N0} days ago' -f $age.TotalDays)
}

# Collects every updatedAt / createdAt date in the status, wherever it sits.
function Get-Timestamps($node) {
    $found = @()
    if ($null -eq $node) { return $found }
    if ($node -is [System.Array]) {
        foreach ($item in $node) { $found += Get-Timestamps $item }
        return $found
    }
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $node.PSObject.Properties) {
            if (($p.Name -eq 'updatedAt' -or $p.Name -eq 'createdAt') -and $p.Value -is [string]) {
                try { $found += [DateTimeOffset]::Parse($p.Value, [Globalization.CultureInfo]::InvariantCulture) } catch { }
            } else {
                $found += Get-Timestamps $p.Value
            }
        }
    }
    return $found
}

# Blanks out anything that identifies the car or where it is.
function Remove-Private($node) {
    if ($null -eq $node) { return }
    if ($node -is [System.Array]) {
        foreach ($item in $node) { Remove-Private $item }
        return
    }
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in @($node.PSObject.Properties)) {
            if ($sensitive -contains $p.Name) { $p.Value = 'REMOVED' } else { Remove-Private $p.Value }
        }
    }
}

# --- Peugeot sign-in settings (public; from the Home Assistant Stellantis integration) ---
$cfgPath = Join-Path $PSScriptRoot '..\App\Resources\peugeot_configs.json'
$brand = (Get-Content -Raw -Encoding UTF8 $cfgPath | ConvertFrom-Json).MyPeugeot
$cc = $Country.ToUpper()
$c = $brand.configs.$cc
if ($null -eq $c) {
    Write-Host "Country '$cc' isn't in Peugeot's list of sign-in countries." -ForegroundColor Red
    exit 1
}

$redirect = "$($brand.scheme)://oauth2redirect/$($cc.ToLower())"
$authUrl = "$($brand.oauth_url)/am/oauth2/authorize?client_id=$($c.client_id)&response_type=code" +
    "&redirect_uri=$redirect&scope=openid%20profile%20email&locale=$($c.locale)"

Write-Host ''
Write-Host 'Peugeot cloud test' -ForegroundColor Cyan
Write-Host '1. Peugeot''s login page opens in your browser now.'
Write-Host '2. BEFORE signing in, press F12 and click the "Console" tab.'
Write-Host '3. Sign in with your MyPeugeot email and password.'
Write-Host '4. The page then goes blank and the Console shows a red line like:'
Write-Host "     Failed to launch 'mymap://oauth2redirect/$($cc.ToLower())?code=...'"
Write-Host '   Copy that mymap:// address and paste it below.'
Write-Host '   The code only works for about a minute, so be quick.'
Write-Host ''
Start-Process $authUrl
$pasted = Read-Host 'Paste the mymap:// address (or just the code)'

if ($pasted -match 'code=([^&\s''"]+)') { $authCode = $Matches[1] } else { $authCode = $pasted.Trim() }
if ([string]::IsNullOrWhiteSpace($authCode)) {
    Write-Host 'Nothing was pasted.' -ForegroundColor Red
    exit 1
}

# --- Trade the one-time code for a temporary token ---
$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($c.client_id):$($c.client_secret)"))
$tokenUrl = "$($brand.oauth_url)/am/oauth2/access_token?redirect_uri=$redirect" +
    "&grant_type=authorization_code&code=$([Uri]::EscapeDataString($authCode))"
try {
    $tok = Invoke-RestMethod -Method Post -Uri $tokenUrl -Headers @{ Authorization = "Basic $basic" } `
        -ContentType 'application/x-www-form-urlencoded' -Body ''
} catch {
    Write-Host "Peugeot refused the code (HTTP $(Get-HttpStatus $_)). It probably expired: run the script again and paste faster." -ForegroundColor Red
    exit 1
}
$access = $tok.access_token
$q = "client_id=$($c.client_id)&locale=$($c.locale)"
$carHeaders = @{ Authorization = "Bearer $access"; 'x-introspect-realm' = $brand.realm; Accept = 'application/hal+json' }

# --- Cars on the account ---
try {
    $list = Invoke-RestMethod -Uri "$api/connectedcar/v4/user/vehicles?$q" -Headers $carHeaders
    $vehicles = @($list._embedded.vehicles | Where-Object { $null -ne $_ })
} catch {
    Write-Host "Couldn't list the cars on your account (HTTP $(Get-HttpStatus $_))." -ForegroundColor Red
    $vehicles = @()
}
if ($vehicles.Count -eq 0) {
    Write-Host ''
    Write-Host 'Verdict: Peugeot''s cloud lists no car on this account -> Plan B (offline companion).' -ForegroundColor Yellow
    Write-Host 'If MyPeugeot shows your car, it is probably getting the data over Bluetooth.'
    exit 0
}

# --- Remote-services link (needed for lock/unlock, horn and lights) ---
$remoteLink = $false
try {
    $otpHeaders = @{ Authorization = "Bearer $access"; 'x-introspect-realm' = $brand.realm; Accept = 'application/hal+json'; 'x-transaction-id' = '1234' }
    $assoc = Invoke-RestMethod -Uri "$api/applications/cvs/v4/mauv/car-associations?$q" -Headers $otpHeaders -UserAgent 'okhttp/4.8.0'
    foreach ($a in @($assoc)) { if ($a.customer) { $remoteLink = $true } }
} catch { }

# --- Status of each car ---
$now = [DateTimeOffset]::UtcNow
$n = 0
foreach ($v in $vehicles) {
    $n++
    $vin = [string]$v.vin
    $vinEnd = $vin
    if ($vin.Length -gt 4) { $vinEnd = '...' + $vin.Substring($vin.Length - 4) }
    Write-Host ''
    Write-Host ("Car {0}: {1} {2} (VIN {3})" -f $n, $v.brand, $v.motorization, $vinEnd) -ForegroundColor Cyan

    try {
        $st = Invoke-RestMethod -Uri "$api/connectedcar/v4/user/vehicles/$($v.id)/status?$q" -Headers $carHeaders
    } catch {
        Write-Host ("  No status from Peugeot's cloud (HTTP {0})." -f (Get-HttpStatus $_)) -ForegroundColor Yellow
        Write-Host '  Verdict: NO CLOUD DATA -> Plan B (offline companion).' -ForegroundColor Yellow
        continue
    }

    $fuel = @($st.energies) | Where-Object { $_.type -eq 'Fuel' } | Select-Object -First 1
    $elec = @($st.energies) | Where-Object { $_.type -eq 'Electric' } | Select-Object -First 1
    if ($fuel) { Write-Host ("  Fuel: {0} %   Range: {1} km" -f $fuel.level, $fuel.autonomy) }
    if ($elec) { Write-Host ("  Battery: {0} %   Range: {1} km" -f $elec.level, $elec.autonomy) }
    if (-not $fuel -and -not $elec) { Write-Host '  Fuel level: not sent' }
    if ($st.odometer) { Write-Host ("  Odometer: {0} km" -f $st.odometer.mileage) } else { Write-Host '  Odometer: not sent' }

    $ds = $st.doorsState
    if ($ds -and $ds.lockedStates) {
        $states = @($ds.lockedStates)
        $locked = @($states | Where-Object { $_ -like '*Locked*' -and $_ -notlike '*Unlocked*' }).Count -gt 0
        $lockText = 'no'
        if ($locked) { $lockText = 'yes' }
        Write-Host ("  Locked: {0} ({1})" -f $lockText, ($states -join ', '))
        $open = @(@($ds.opening) | Where-Object { $_.state -eq 'Open' } | ForEach-Object { $_.identifier })
        if ($open.Count -gt 0) { Write-Host ("  Open: {0}" -f ($open -join ', ')) }
    } else {
        Write-Host '  Lock state: not sent'
    }

    $hasPos = ($null -ne $st.lastPosition) -and ($null -ne $st.lastPosition.geometry) -and ($null -ne $st.lastPosition.geometry.coordinates)
    $posText = 'no'
    if ($hasPos) { $posText = 'yes (not shown here)' }
    Write-Host ("  Position sent by the car: {0}" -f $posText)

    $mUrls = @()
    if ($v._links -and $v._links.maintenance -and $v._links.maintenance.href) { $mUrls += [string]$v._links.maintenance.href }
    $mUrls += "$api/connectedcar/v4/user/vehicles/$($v.id)/maintenance"
    foreach ($u in $mUrls) {
        $sep = '?'
        if ($u.Contains('?')) { $sep = '&' }
        try {
            $m = Invoke-RestMethod -Uri "$u$sep$q" -Headers $carHeaders
            if ($null -ne $m.mileageBeforeMaintenance -or $null -ne $m.daysBeforeMaintenance) {
                Write-Host ("  Next service: in {0} km / {1} days" -f $m.mileageBeforeMaintenance, $m.daysBeforeMaintenance)
                break
            }
        } catch { }
    }

    $remoteText = 'no'
    if ($remoteLink) { $remoteText = 'yes' }
    Write-Host ("  Remote-services link (needed for lock/unlock): {0}" -f $remoteText)

    $stamps = @(Get-Timestamps $st)
    if ($stamps.Count -eq 0) {
        Write-Host '  Verdict: UNCLEAR - data came back without dates. Drive the car, run this again and check the numbers changed.' -ForegroundColor Yellow
    } else {
        $newest = $stamps | Sort-Object -Descending | Select-Object -First 1
        $age = $now - $newest
        Write-Host ("  Newest data from the car: {0:yyyy-MM-dd HH:mm} ({1})" -f $newest.ToLocalTime(), (Format-Age $age))
        if ($age.TotalDays -le 2) {
            Write-Host '  Verdict: LIVE - Peugeot''s cloud gets data from this car -> Plan A (connected app).' -ForegroundColor Green
        } else {
            Write-Host ("  Verdict: STALE - the newest data is {0}." -f (Format-Age $age)) -ForegroundColor Yellow
            Write-Host '    If you drove since then, Peugeot''s cloud isn''t getting updates -> Plan B.'
            Write-Host '    If the car was parked the whole time, drive 15+ minutes and run this again.'
        }
    }

    if ($SaveSample) {
        Remove-Private $st
        $outPath = Join-Path $PSScriptRoot ("status-sample-{0}.json" -f $n)
        $st | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 $outPath
        Write-Host "  Saved a cleaned copy of the status to $outPath"
    }
}

$access = $null
$tok = $null
Write-Host ''
if ($SaveSample) {
    Write-Host 'Done. Only the cleaned sample file(s) were saved; the token is forgotten now.'
} else {
    Write-Host 'Done. Nothing was saved; the token is forgotten now.'
}
