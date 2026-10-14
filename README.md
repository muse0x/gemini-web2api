# gemini-web2api

<p align="center">
  <img src="logo.png" width="200" alt="gemini-web2api logo">
</p>

[Tiếng Việt](README_VI.md)

Convert Google Gemini's web interface into an OpenAI-compatible API. Zero cost, cross-platform, single file.

## Features

- **Optional API Keys**: no auth when `api_keys` is empty, OpenAI-style Bearer auth when configured
- **OpenAI Compatible**: Drop-in replacement for `/v1/chat/completions` and `/v1/models`
- **Tool Calling**: Full function calling support (OpenAI format)
- **Multiple Models**: Gemini 4 Argon, 3.8 Flash, 3.6 Flash, 3.5 Flash-Lite, 3.1 Pro Preview, Auto
- **Gemini Thinking Levels**: `low`, `medium`, and `high`; selectable as OpenCode variants or via `@think=N`
- **Web Search**: Built-in internet access (Gemini's native search)
- **Cross-Platform**: Pure Python, single optional dependency (`httpx` for streaming)
- **Streaming**: SSE streaming support via `httpx`
- **Codex CLI**: Responses API (`/v1/responses`) for OpenAI Codex integration
- **OpenCode**: custom OpenAI-compatible provider using `/v1/chat/completions`
- **Claude Code**: Anthropic Messages API (`/v1/messages`) with tool calls and SSE
- **Gemini CLI**: Google native API (`/v1beta/models`) for Gemini CLI compatibility

## Quick Start

```bash
pip install httpx
python gemini_web2api.py
```

Server starts at `http://localhost:8081/v1`.

### Windows: one-command client setup

From the repository folder, run this in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

The script installs the optional `httpx` dependency if needed and creates or
updates the local server and client configs. OpenCode defaults to **GW - Gemini
4 Argon**; the Codex desktop app and Claude Code VS Code extension use
`gemini-3.8-flash`. Argon requires an eligible Gemini account and cookie. The
server runs in the background on `127.0.0.1`. OpenCode gets Gemini Web's three
thinking levels automatically. Restart OpenCode, the ChatGPT/Codex
app, and VS Code after the command completes. The Claude Code extension must
already be installed in VS Code; this configures the VS Code extension, not
Claude Desktop.

Existing client settings are merged and backed up under
`%LOCALAPPDATA%\Gemini Web2API\backups`. The API key is generated locally and
stored in ignored `config.json` plus the client settings. The server runs for the
current Windows session; run the setup command again after restarting Windows.
Logs are written to `%LOCALAPPDATA%\Gemini Web2API\server.log` and
`server-error.log`.

## Client Configuration

### Cherry Studio / ChatBox / any OpenAI client

| Field | Value |
|-------|-------|
| Base URL | `http://localhost:8081/v1` |
| API Key | any `api_keys` value from `config.json`; anything if not configured |
| Model | `gemini-3.8-flash` |

### curl

#### bash / macOS / Linux

```bash
curl http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-key" \
  -d '{"model":"gemini-3.8-flash","messages":[{"role":"user","content":"Hello!"}]}'
```

#### PowerShell (Windows)

```powershell
curl.exe --% http://127.0.0.1:8081/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer sk-your-key" -d "{\"model\":\"gemini-3.8-flash\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}"
```

> Note: On Windows PowerShell, use `curl.exe` and `--%` so PowerShell does not reinterpret JSON quoting or curl options.

### OpenAI Python SDK

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8081/v1", api_key="sk-your-key")
resp = client.chat.completions.create(
    model="gemini-3.8-flash@think=0",
    messages=[{"role": "user", "content": "Explain quantum computing"}]
)
print(resp.choices[0].message.content)
```

### OpenCode

Add this provider to `opencode.json` and set `GEMINI_WEB2API_API_KEY` to a key
from `config.json`. Replace the URL with your Cloudflare Worker URL when using
the Worker deployment.

In PowerShell, set the key for the current terminal session with:

```powershell
$env:GEMINI_WEB2API_API_KEY = "your-key"
```

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "gemini-web2api/gemini-4-argon",
  "provider": {
    "gemini-web2api": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Gemini Web2API",
      "options": {
        "baseURL": "http://127.0.0.1:8081/v1",
        "apiKey": "{env:GEMINI_WEB2API_API_KEY}"
      },
      "models": {
        "gemini-4-argon": {
          "name": "GW - Gemini 4 Argon",
          "variants": {
            "low": { "reasoningEffort": "low" },
            "medium": { "reasoningEffort": "medium" },
            "high": { "reasoningEffort": "high" }
          }
        },
        "gemini-3.8-flash": {
          "name": "GW - Gemini 3.8 Flash",
          "variants": {
            "low": { "reasoningEffort": "low" },
            "medium": { "reasoningEffort": "medium" },
            "high": { "reasoningEffort": "high" }
          }
        }
      }
    }
  }
}
```

If API-key authentication is disabled, remove the `apiKey` field.

The one-command setup adds Gemini Web's three thinking levels to both OpenCode
models: `low` (`think=4`), `medium` (`think=2`), and `high` (`think=0`). Select a
level in OpenCode's model picker. Claude Code and Codex send their own effort
fields; the server maps `none`/`minimal`/`low` to Gemini `low`, `medium` to
Gemini `medium`, and `high`/`xhigh`/`max` to Gemini `high`. Their extra effort
values do not create additional Gemini levels.

### Claude Code

In PowerShell, point Claude Code at the Anthropic-compatible endpoint and pass
one of the Gemini model IDs:

```powershell
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8081"
$env:ANTHROPIC_AUTH_TOKEN = "sk-your-key"
claude --model gemini-3.8-flash
```

For Cloudflare Workers, use the Worker origin as `ANTHROPIC_BASE_URL`.
Claude Code uses `/v1/messages`; this project translates its Messages API
requests, tool calls, and streaming events to Gemini Web.

### Gemini CLI

```bash
export GEMINI_API_KEY=none
export GOOGLE_GEMINI_BASE_URL=http://localhost:8081
gemini
```

Supports Google native API endpoints:
- `GET /v1beta/models` — list models
- `POST /v1beta/models/{model}:generateContent` — non-streaming
- `POST /v1beta/models/{model}:streamGenerateContent` — streaming (SSE)

## Available Models

| Model ID | Tier | Notes |
|-----------|------|-------|
| `gemini-4-argon` | Argon | Requires an eligible Google AI plan and account cookie |
| `gemini-3.8-flash` | Flash | Current Gemini Flash model |
| `gemini-3.6-flash` | Flash | Previous-generation Flash model |
| `gemini-3.5-flash-lite` | Flash-Lite | Fast, cost-efficient model |
| `gemini-3.1-pro-preview` | Pro | Preview model; requires an eligible account cookie |
| `gemini-auto` | Auto | Gemini selects a model |

### Thinking Levels

Append `@think=N` to any model name:

```
gemini-3.8-flash@think=0   # high
gemini-3.8-flash@think=2   # medium
gemini-3.8-flash@think=4   # low
```

The API reads OpenAI Chat Completions effort (`reasoning_effort` or OpenCode's
`reasoningEffort`), OpenAI Responses effort (`reasoning.effort`), and Anthropic
Messages effort (`output_config.effort`). An explicit `@think=N` suffix takes
precedence over the request effort field.

## Optional: Cookie for Pro and Argon

Pro and Argon availability depends on the Google AI plan and account. The repository includes a Chrome/Edge extension that exports the signed-in Gemini session and page metadata locally.

### Quick setup with Gemini Cookie Sync

1. Open `chrome://extensions` in Chrome or `edge://extensions` in Edge, enable **Developer mode**, and choose **Load unpacked**.
2. Select this repository's `gemini-cookie-sync-extension` folder.
3. Open [Gemini](https://gemini.google.com/app), sign in to the eligible account, and refresh the page.
4. Open the **Gemini Cookie Sync** extension and click **Inspect session**. When it says the session and XSRF are ready, click **Export gemini-auth.json** and save it as `gemini-auth.json` in the repository root.

The extension reads the current Google session and Gemini page metadata in the browser, then downloads the JSON locally; it does not send the session to a server. `gemini-auth.json` contains login credentials and is already ignored by Git. Never paste or share it.

From PowerShell at the repository root, run `setup.ps1` once if `config.json` does not exist. Then merge the exported values; this preserves the other server settings:

```powershell
$auth = Get-Content .\gemini-auth.json -Raw | ConvertFrom-Json
$configPath = (Resolve-Path .\config.json).Path
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$config | Add-Member -MemberType NoteProperty -Name cookie_file -Value (Resolve-Path .\gemini-auth.json).Path -Force
$config | Add-Member -MemberType NoteProperty -Name auth_user -Value $auth.auth_user -Force
$config | Add-Member -MemberType NoteProperty -Name xsrf_token -Value $auth.xsrf_token -Force
if ($auth.gemini_bl) { $config | Add-Member -MemberType NoteProperty -Name gemini_bl -Value $auth.gemini_bl -Force }
[System.IO.File]::WriteAllText($configPath, (($config | ConvertTo-Json -Depth 100) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
```

Restart the server so it reloads both files, then restart OpenCode. It defaults to **GW - Gemini 4 Argon**. To start the server manually, run `python gemini_web2api.py` from the repository root. See [`gemini-cookie-sync-extension/SETUP.md`](gemini-cookie-sync-extension/SETUP.md) for the full steps. A valid session does not grant access to models the account's plan cannot use.

If **Inspect session** reports missing XSRF, refresh Gemini and inspect again. If an authenticated request still returns HTTP 400 with an `xsrf` error, export a fresh file and restart the server. The extension exports `auth_user`, `xsrf_token`, and `gemini_bl` alongside the cookie.

## Configuration

Create `config.json` in the same directory:

```json
{
  "port": 8081,
  "host": "0.0.0.0",
  "retry_attempts": 3,
  "retry_delay_sec": 2,
  "request_timeout_sec": 180,
  "gemini_bl": "boq_assistant-bard-web-server_20260716.08_p0",
  "auth_user": null,
  "xsrf_token": null,
  "api_keys": ["sk-your-key"],
  "cookie_file": null,
  "proxy": null,
  "log_requests": true,
  "temporary_chats": false
}
```

Set `temporary_chats` to `true` to use Gemini Web temporary chats instead of
persisting conversations to the account history.

When `api_keys` is `[]`, authentication is disabled. When one or more keys are set, `/v1/*` endpoints require `Authorization: Bearer <key>` or `x-api-key: <key>`.

## Docker

```bash
cp config.example.json config.json
docker build -t gemini-web2api .
docker run -d --name gemini-web2api -p 8081:8081 -v ./config.json:/app/config.json gemini-web2api
```

Or use Docker Compose:

```bash
cp config.example.json config.json
docker compose up -d
```

To mount a cookie file:

```bash
docker run -d --name gemini-web2api -p 8081:8081 -v ./config.json:/app/config.json -v ./cookie.txt:/app/cookie.txt gemini-web2api
```

Set `"cookie_file": "/app/cookie.txt"` in `config.json`.

> **Note**: If you get empty responses (`content: null`) with Docker's default bridge network, switch to host networking: `docker run --network host ...` or add `network_mode: host` in your compose file. This is caused by Gemini's upstream rejecting requests from certain Docker NAT IP ranges.

## Proxy

If you cannot access `gemini.google.com` directly (connection timeout), configure a proxy:

**Method 1: CLI argument**
```bash
python gemini_web2api.py --proxy http://127.0.0.1:7890
```

**Method 2: config.json**
```json
{"proxy": "http://127.0.0.1:7890"}
```

**Method 3: Environment variable** (auto-detected)
```bash
export HTTPS_PROXY=http://127.0.0.1:7890
python gemini_web2api.py
```

Works with Clash, V2Ray, Shadowsocks, or any HTTP proxy.

## Tool Calling

```python
resp = client.chat.completions.create(
    model="gemini-3.8-flash",
    messages=[{"role": "user", "content": "What's the weather in Tokyo?"}],
    tools=[{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get weather for a city",
            "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}
        }
    }]
)
```

## Image Input

OpenAI-style multimodal messages are supported for Chat Completions and the
Responses API. Use either HTTP(S) image URLs or base64 data URLs:

```python
resp = client.chat.completions.create(
    model="gemini-3.8-flash",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "Describe this image"},
            {"type": "image_url", "image_url": {"url": "https://example.com/image.png"}}
        ]
    }]
)
```

## Limitations

- **Image upload may require cookies**: Multimodal input uses Gemini Web's image upload endpoint. If anonymous upload fails, configure a Gemini cookie.
- **Plan-dependent tiers**: Pro and Argon routing depends on the signed-in account's plan and model availability.
- **Single-turn only**: Each request is an independent conversation. Multi-turn context is simulated by including previous messages in the prompt.
- **Rate limits**: Google may throttle high-frequency requests. The server retries automatically but sustained heavy use may be blocked.

## Requirements

- Python 3.8+
- `httpx` (`pip install httpx`) — used for streaming requests
- Network access to `gemini.google.com` (proxy/VPN may be needed in some regions)

## How It Works

This tool reverse-engineers Google Gemini's web StreamGenerate protocol. It sends requests to the same endpoint that the Gemini web app uses, converting between OpenAI's API format and Gemini's internal protobuf-like format.

The model selection is controlled by field `[79]` in the request payload, mapped from Gemini's frontend JavaScript source (`MODE_CATEGORY` enum).

## Acknowledgments

- Inspired by the open-source API proxy ecosystem
- Agent capabilities during development are provided by [GenericAgent](https://github.com/lsdefine/GenericAgent).
- Thanks to the [LinuxDo community](https://linux.do/).

## License

MIT
