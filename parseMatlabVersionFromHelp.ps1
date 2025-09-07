# Parse MATLAB version info from `matlab -help` output
# Usage: powershell -ExecutionPolicy Bypass -File parseMatlabVersionFromHelp.ps1

$ErrorActionPreference = 'SilentlyContinue'

function Write-VersionResult($obj) {
    if ($obj) { Write-Output $obj } else { Write-Output 'MATLAB version not detected' }
}

# Run matlab -help capturing both stdout/stderr
try {
    $raw = & matlab -help 2>&1
} catch {
    Write-Error 'matlab command not found or failed to execute.'
    exit 1
}

if (-not $raw) {
    Write-Output 'No output from matlab -help'
    exit 1
}

# Join for easier multi-line regex if needed
$joined = $raw -join "`n"

# Common pattern: "MATLAB Version: 9.15.0.2190032 (R2023b) Update 2" etc.
$pattern1 = 'MATLAB\s+Version:\s*(?<core>[0-9]+\.[0-9]+(?:\.[0-9]+)*)\s*\((?<release>R20[0-9]{2}[ab])\)\s*(?:Update\s*(?<upd>\d+))?'
$match1 = [regex]::Match($joined, $pattern1, 'IgnoreCase')
if ($match1.Success) {
    $core = $match1.Groups['core'].Value
    $release = $match1.Groups['release'].Value
    $upd = $match1.Groups['upd'].Value
    $ver = if ($upd) { "$core ($release) Update $upd" } else { "$core ($release)" }
    Write-VersionResult $ver
    exit 0
}

# Fallback pattern e.g. sometimes only shows (R2024a)
$pattern2 = 'MATLAB\s+(?<release>R20[0-9]{2}[ab])'
$match2 = [regex]::Match($joined, $pattern2, 'IgnoreCase')
if ($match2.Success) {
    Write-VersionResult $match2.Groups['release'].Value
    exit 0
}

# Another fallback: line starting with MATLAB Version without release parentheses
$pattern3 = 'MATLAB\s+Version:\s*(?<core>[0-9]+\.[0-9]+(?:\.[0-9]+)*)'
$match3 = [regex]::Match($joined, $pattern3, 'IgnoreCase')
if ($match3.Success) {
    Write-VersionResult $match3.Groups['core'].Value
    exit 0
}

Write-VersionResult $null
exit 2
