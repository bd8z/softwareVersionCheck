# PowerShell script to parse MATLAB version from output.log

# Path to the log file
$logPath = "output.log"

# Check if the log file exists
if (-Not (Test-Path $logPath)) {
    Write-Error "Log file not found: $logPath"
    exit 1
}

# Read and parse the log file
try {
    $content = Get-Content $logPath
    $parsedMatches = $content | Select-String -Pattern "MATLAB バージョン:\s*(.+)" | ForEach-Object {
        ($_ -match "MATLAB バージョン:\s*(.+)") | Out-Null
        $matches[1]
    }

    if ($parsedMatches) {
        $parsedMatches | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No MATLAB version information found in the log."
    }
} catch {
    Write-Error "Failed to parse the log file: $_"
    exit 1
}
