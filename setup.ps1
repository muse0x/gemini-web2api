$ErrorActionPreference = "Stop"

function Set-JsonProperty {
    param([object]$Object, [string]$Name, [object]$Value)
    $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
}

function Read-JsoncFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return [pscustomobject]@{} }

    $content = [System.IO.File]::ReadAllText($Path)
    $content = [regex]::Replace($content, '(?s)("(?:\\.|[^"\\])*")|//[^\r\n]*|/\*.*?\*/', {
        param($match)
        if ($match.Groups[1].Success) { return $match.Groups[1].Value }
        return " " + [regex]::Replace($match.Value, '[^\r\n]', "")
    })
    $content = [regex]::Replace($content, '("(?:\\.|[^"\\])*")|,(?=\s*[}\]])', '$1')
    return ConvertFrom-Json $content
}

function Write-TextFile {
    param([string]$Path, [string]$Text, [string]$BackupName)
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    $backupPath = Join-Path $backupDirectory "$BackupName.gemini-web2api.bak"
    if ((Test-Path $Path) -and -not (Test-Path $backupPath)) {
        Copy-Item -LiteralPath $Path -Destination $backupPath
    }
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Write-JsoncFile {
    param([string]$Path, [object]$Object, [string]$BackupName)
    Write-TextFile $Path (($Object | ConvertTo-Json -Depth 100) + [Environment]::NewLine) $BackupName
}

function Set-TomlRootValue {
    param([string]$Text, [string]$Name, [string]$Value)
    $section = [regex]::Match($Text, '(?m)^\s*\[')
    $root = if ($section.Success) { $Text.Substring(0, $section.Index) } else { $Text }
    $rest = if ($section.Success) { $Text.Substring($section.Index) } else { "" }
    $pattern = "(?m)^\s*$([regex]::Escape($Name))\s*=.*$"
    $line = "$Name = `"$Value`""
    if ([regex]::IsMatch($root, $pattern)) {
        $root = [regex]::Replace($root, $pattern, { param($match) $line }, 1)
    } else {
        $root = $root.TrimEnd() + "`r`n$line`r`n"
    }
    return $root + $rest
}

$serverPath = Join-Path $PSScriptRoot "gemini_web2api.py"
if (-not (Test-Path $serverPath)) { throw "Run this script from the gemini-web2api repository." }

$backupDirectory = Join-Path $env:LOCALAPPDATA "Gemini Web2API\backups"
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$pythonCommand = Get-Command py -ErrorAction SilentlyContinue
$pythonExe = if ($pythonCommand) { (& $pythonCommand.Source -3 -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1) }
if (-not $pythonExe) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    $pythonExe = if ($pythonCommand) { $pythonCommand.Source }
}
if (-not $pythonExe -or -not (Test-Path $pythonExe)) { throw "Python 3 is required. Install Python 3, then run this command again." }

& $pythonExe -c "import httpx" 2>$null
if ($LASTEXITCODE -ne 0) {
    & $pythonExe -m pip install httpx
    if ($LASTEXITCODE -ne 0) { throw "Could not install httpx with the selected Python interpreter." }
}

$serverConfigPath = Join-Path $PSScriptRoot "config.json"
$serverConfig = Read-JsoncFile $serverConfigPath
$apiKeys = @($serverConfig.api_keys | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$apiKey = if ($apiKeys.Count) { [string]$apiKeys[0] } else { "sk-gemini-" + [guid]::NewGuid().ToString("N") }
if ($apiKey -match '[\r\n]') { throw "The first API key in config.json contains a line break; replace it before running setup." }
$apiKeys = if ($apiKeys.Count) { $apiKeys } else { @($apiKey) }
$port = if ($serverConfig.port) { [int]$serverConfig.port } else { 8081 }
$baseUrl = "http://127.0.0.1:$port"
$logDirectory = Join-Path $env:LOCALAPPDATA "Gemini Web2API"
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$serverRunning = $false
try {
    Invoke-RestMethod -Uri "$baseUrl/v1/models" -Headers @{ Authorization = "Bearer $apiKey" } -TimeoutSec 2 | Out-Null
    $serverRunning = $true
} catch {
    if ($_.Exception.Response) { throw "Port $port is already in use by a server that did not accept this API key." }
}

Set-JsonProperty $serverConfig "host" "127.0.0.1"
Set-JsonProperty $serverConfig "port" $port
Set-JsonProperty $serverConfig "api_keys" $apiKeys
Set-JsonProperty $serverConfig "default_model" "gemini-3.8-flash"
Write-JsoncFile $serverConfigPath $serverConfig "server-config.json"

$openCodePath = Join-Path $env:USERPROFILE ".config\opencode\opencode.json"
$openCode = Read-JsoncFile $openCodePath
if (-not $openCode.provider) { Set-JsonProperty $openCode "provider" ([pscustomobject]@{}) }
Set-JsonProperty $openCode.provider "gemini-web2api" ([pscustomobject]@{
    npm = "@ai-sdk/openai-compatible"
    name = "Gemini Web2API"
    options = [pscustomobject]@{ baseURL = "$baseUrl/v1"; apiKey = $apiKey }
    models = [pscustomobject]@{
        "gemini-4-argon" = [pscustomobject]@{ name = "GW - Gemini 4 Argon" }
        "gemini-3.8-flash" = [pscustomobject]@{ name = "GW - Gemini 3.8 Flash" }
    }
})
Set-JsonProperty $openCode "model" "gemini-web2api/gemini-4-argon"
if (-not $openCode.'$schema') { Set-JsonProperty $openCode '$schema' "https://opencode.ai/config.json" }
Write-JsoncFile $openCodePath $openCode "opencode.json"

$vscodePath = Join-Path $env:APPDATA "Code\User\settings.json"
$vscodeSettings = Read-JsoncFile $vscodePath
Set-JsonProperty $vscodeSettings "claudeCode.environmentVariables" @(
    [pscustomobject]@{ name = "ANTHROPIC_BASE_URL"; value = $baseUrl }
    [pscustomobject]@{ name = "ANTHROPIC_AUTH_TOKEN"; value = $apiKey }
    [pscustomobject]@{ name = "ANTHROPIC_MODEL"; value = "gemini-3.8-flash" }
)
Set-JsonProperty $vscodeSettings "claudeCode.disableLoginPrompt" $true
Write-JsoncFile $vscodePath $vscodeSettings "vscode-settings.json"

$codexDirectory = Join-Path $env:USERPROFILE ".codex"
$codexConfigPath = Join-Path $codexDirectory "config.toml"
$codexConfig = if (Test-Path $codexConfigPath) { [System.IO.File]::ReadAllText($codexConfigPath) } else { "" }
$codexConfig = Set-TomlRootValue $codexConfig "model" "gemini-3.8-flash"
$codexConfig = Set-TomlRootValue $codexConfig "model_provider" "gemini-web2api"
$providerBlock = @"
[model_providers.gemini-web2api]
name = "Gemini Web2API"
base_url = "$baseUrl/v1"
env_key = "GEMINI_WEB2API_API_KEY"
wire_api = "responses"
requires_openai_auth = false
supports_websockets = false
"@
$providerPattern = '(?ms)^\[model_providers\.gemini-web2api\]\r?\n.*?(?=^\[|\z)'
$codexConfig = if ([regex]::IsMatch($codexConfig, $providerPattern)) {
    [regex]::Replace($codexConfig, $providerPattern, $providerBlock.Trim() + "`r`n", 1)
} else {
    $codexConfig.TrimEnd() + "`r`n`r`n" + $providerBlock.Trim() + "`r`n"
}
Write-TextFile $codexConfigPath $codexConfig "codex-config.toml"

$codexEnvPath = Join-Path $codexDirectory ".env"
$codexEnv = if (Test-Path $codexEnvPath) { [System.IO.File]::ReadAllText($codexEnvPath) } else { "" }
$envLine = "GEMINI_WEB2API_API_KEY=$apiKey"
$envPattern = '(?m)^GEMINI_WEB2API_API_KEY=.*$'
$codexEnv = if ([regex]::IsMatch($codexEnv, $envPattern)) {
    [regex]::Replace($codexEnv, $envPattern, $envLine)
} else {
    $codexEnv.TrimEnd() + "`r`n$envLine`r`n"
}
Write-TextFile $codexEnvPath $codexEnv "codex.env"

if (-not $serverRunning) {
    Start-Process -FilePath $pythonExe `
        -ArgumentList @('"' + $serverPath + '"') `
        -WorkingDirectory $PSScriptRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDirectory "server.log") `
        -RedirectStandardError (Join-Path $logDirectory "server-error.log") | Out-Null
}

Write-Host "Gemini Web2API is configured for OpenCode, Codex, and the Claude Code VS Code extension."
Write-Host "Local API: $baseUrl/v1 | Model: gemini-3.8-flash"
Write-Host "The server runs hidden; restart the three apps to load the new settings."
Write-Host "Backups of existing settings are in: $backupDirectory"
