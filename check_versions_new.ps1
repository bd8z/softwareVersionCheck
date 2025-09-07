# PowerShell: Software Version Check (Integrated JSON, UTF-8/BOM-less + JS export)

# Path settings (テキストログは出力しない方針だが既存残骸削除用にパス保持)
$logPath    = "C:\Users\bridg\Documents\github\softwareVersionCheck\version_check.log"
$jsDataPath = "C:\Users\bridg\Documents\github\softwareVersionCheck\version_data.js"  # JS履歴

# Integrated software list
$softwareList = @(
    @{ name = "Git"; command = "git --version" },
    @{ name = "Matlab"; command = "powershell -File c:\\Users\\bridg\\Documents\\github\\softwareVersionCheck\\getMatlabVersion.ps1 -ExecutionPolicy Bypass" },
    @{ name = "Prometheus"; command = "prometheus --version" },
    @{ name = "gitlab-runner"; command = "gitlab-runner --version" }
)

Write-Host "Software list:"
foreach ($sw in $softwareList) {
    Write-Host "- $($sw.name)"
}

# Hostname 追加
$hostname = $env:COMPUTERNAME

# （テキストログ出力廃止）

# Parallel execution
$jobs = @()
foreach ($sw in $softwareList) {
    $name = $sw.name
    $cmdStr = $sw.command
    Write-Host "Run command: $name"
    if ([string]::IsNullOrWhiteSpace($cmdStr)) {
        Write-Host "Command not defined or unsupported: $name"
        continue
    }
    $jobs += Start-Job -ScriptBlock {
        param($name, $cmdStr)
        try {
            $out = Invoke-Expression $cmdStr
        } catch {
            $out = $null
        }
        if ($out) {
            return "[$name] $out"
        } else {
            return "[$name] Not installed or failed to get version"
        }
    } -ArgumentList $name, $cmdStr
}

# Collect results
$results = $jobs | ForEach-Object {
    $job = $_
    $output = Receive-Job -Job $job -Wait
    Remove-Job -Job $job

    # MATLAB 特殊処理（テンポラリログ名固定）
    if ($output -like "*matlab_version.log*") {
        $matlabTmp = "matlab_version.log"
        if (Test-Path $matlabTmp) {
            $matlabVersion = Get-Content $matlabTmp | Select-String -Pattern "MATLAB" | ForEach-Object { $_.ToString().Trim() }
            Remove-Item $matlabTmp -ErrorAction SilentlyContinue
            return "[Matlab] $matlabVersion"
        } else {
            return "[Matlab] Version log not found"
        }
    }

    $output
}
# テキストログ書き込みは行わない（要求により廃止）

# ===== JS Export (window.versionMatrix に push する1レコード) =====
# 既存結果をパースして1ホスト分の辞書を生成
$record = [ordered]@{
    timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    host      = $hostname
}

# 初期化: 全ソフト名を空文字でセット
foreach ($sw in $softwareList) { $record[$sw.name] = "" }

foreach ($line in $results) {
    if ($line -match '^\[(.+?)\]\s+(.*)$') {
        $n = $matches[1]
        $v = $matches[2]
        if ($record.Contains($n)) { $record[$n] = $v }
    }
}

$json = ($record | ConvertTo-Json -Depth 3 -Compress)
$jsLine = "window.versionMatrix = window.versionMatrix || []; window.versionMatrix.push($json);"

if (-not (Test-Path $jsDataPath)) {
    Set-Content -Path $jsDataPath -Value "/** Generated version data history. */" -Encoding UTF8
}
Add-Content -Path $jsDataPath -Value $jsLine -Encoding UTF8
Write-Host ("JS data appended: {0}" -f $jsDataPath)

# 後片付け: 既存の旧ログがあれば削除
if (Test-Path $logPath) { Remove-Item $logPath -ErrorAction SilentlyContinue }
if (Test-Path "matlab_version.log") { Remove-Item "matlab_version.log" -ErrorAction SilentlyContinue }
