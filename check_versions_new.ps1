# PowerShell: Software Version Check (Integrated JSON, UTF-8/BOM-less + JS export)

# Path settings (テキストログは出力しない方針だが既存残骸削除用にパス保持)
$logPath    = "C:\Users\bridg\Documents\github\softwareVersionCheck\version_check.log"
# 出力先を assets/version_data.js に変更 (スクリプト位置基準)
$jsDataPath = Join-Path $PSScriptRoot 'assets' | Join-Path -ChildPath 'version_data.js'

# 毎回最新のみ保持するため既存version_data.jsを削除
if (Test-Path $jsDataPath) { Remove-Item $jsDataPath -ErrorAction SilentlyContinue }

# Integrated software list
$softwareList = @(
    @{ name = "Git"; command = "git --version" },
    # Matlab: inline parser using 'matlab -help' output (here-string for readability)
    @{ name = "Matlab"; command = @'
& {
        try {
            $raw = & matlab -help 2>&1
            if(-not $raw){ 'Not installed or failed to get version'; return }
            $joined = $raw -join "`n"
            $m = [regex]::Match($joined,'MATLAB\s+Version:\s*([0-9]+\.[0-9]+(?:\.[0-9]+)*)\s*\((R20[0-9]{2}[ab])\)\s*(?:Update\s*(\d+))?',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if($m.Success){
                $core=$m.Groups[1].Value; $rel=$m.Groups[2].Value; $upd=$m.Groups[3].Value
                if($upd){ "$core ($rel) Update $upd" } else { "$core ($rel)" }
            } else {
                $plain = $raw | Where-Object { $_ -match '^\s*Version:\s*([0-9]+(\.[0-9]+){1,3})' } | Select-Object -First 1
                if($plain){ $null = $plain -match '^\s*Version:\s*([0-9]+(\.[0-9]+){1,3})'; $matches[1] } else { 'Not installed or failed to get version' }
            }
        } catch { 'Not installed or failed to get version' }
}
'@ },
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

    # （Matlab は inline parser へ移行済み）

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
# 最新のみ出力: 毎回ファイルを上書きして単一レコードだけ保持
$header = @('/** Generated version data (latest only). */', 'window.versionMatrix = [];') -join "`n"
$body   = "window.versionMatrix.push($json);"
Set-Content -Path $jsDataPath -Value ($header + "`n" + $body) -Encoding UTF8
Write-Host ("JS data overwritten with latest record: {0}" -f $jsDataPath)

# ===== Standalone HTML Bundle 生成 =====
try {
        $cssPath   = Join-Path $PSScriptRoot 'assets' | Join-Path -ChildPath 'styles.css'
        $appJsPath = Join-Path $PSScriptRoot 'assets' | Join-Path -ChildPath 'app.js'
        $bundlePath = Join-Path $PSScriptRoot 'version_matrix_standalone.html'

        $styles = ''
        if (Test-Path $cssPath) { $styles = Get-Content $cssPath -Raw -Encoding UTF8 }
        $appJs = ''
        if (Test-Path $appJsPath) { $appJs = Get-Content $appJsPath -Raw -Encoding UTF8 }
        $dataJs = ''
        if (Test-Path $jsDataPath) { $dataJs = Get-Content $jsDataPath -Raw -Encoding UTF8 }

            $bundle = @"
    <!DOCTYPE html>
    <html lang=\"ja\">
    <head>
        <meta charset=\"UTF-8\" />
        <meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\" />
        <title>Version Matrix</title>
    <style>
$styles
    </style>
</head>
<body>
        <header><h1>VERSION MATRIX</h1></header>
    <main>
        <section class="panel">
            <div class="controls">
                <button id="reloadBtn" title="リロード">RELOAD</button>
                <input id="hostFilter" type="text" class="host-filter" placeholder="Host filter (regex可)" />
                <button id="clearFilterBtn" class="btn-alt">CLEAR</button>
                <span class="page-load-indicator">Loaded: <span id="pageLoadTime">-</span></span>
            </div>
            <div class="table-container">
                <table id="logTable" class="matrix">
                    <thead><tr><th>Host</th><th>Checked (Age)</th><th>Git</th><th>Matlab</th><th>Prometheus</th><th>gitlab-runner</th></tr></thead>
                    <tbody></tbody>
                </table>
            </div>
                <details class="help"><summary>説明 / ヘルプ</summary>
                    <ul><li>データソース: <code>assets/version_data.js</code>（最新1件のみ上書き保存）</li><li>PowerShell 実行毎に最新版を書き出し → RELOAD ボタンで再読込</li><li>Age: 取得時刻との差（日数, 小数1桁）</li></ul>
            </details>
        </section>
    </main>
    <script>
$dataJs
    </script>
    <script>
$appJs
    </script>
</body>
</html>
"@

        Set-Content -Path $bundlePath -Value $bundle -Encoding UTF8
        Write-Host ("Standalone bundle generated: {0}" -f $bundlePath)
} catch {
        Write-Warning "Standalone bundle generation failed: $($_.Exception.Message)"
}

# 後片付け: 既存の旧ログがあれば削除
if (Test-Path $logPath) { Remove-Item $logPath -ErrorAction SilentlyContinue }
if (Test-Path "matlab_version.log") { Remove-Item "matlab_version.log" -ErrorAction SilentlyContinue }
