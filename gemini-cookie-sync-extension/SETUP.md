# Gemini Cookie Sync Setup

Short guide for extracting fresh Gemini auth data and applying it to `gemini-web2api`.

## What this extension exports

The extension reads the current signed-in Gemini session and exports:

- Google session cookies
- `SAPISID`
- `SNlM0e` (`xsrf_token`)
- `cfb2h` (`gemini_bl`)
- `auth_user`

It saves them locally as `gemini-auth.json`.

## Install and export

1. Open `chrome://extensions` in Chrome or `edge://extensions` in Edge
2. Enable **Developer mode**
3. Click **Load unpacked**
4. Select the `gemini-cookie-sync-extension` folder
5. Open [https://gemini.google.com/app](https://gemini.google.com/app)
6. Sign in and refresh the page
7. Open the extension and click **Inspect session**
8. Confirm the session looks ready
9. Click **Export gemini-auth.json**

Expected ready state:

```text
XSRF / SNlM0e: present
gemini_bl / cfb2h: present
Session and XSRF are ready for export.
```

## Windows: apply it to this repository

Save the downloaded `gemini-auth.json` in the repository root. If `config.json` does not exist yet, run `setup.ps1` once from PowerShell in the repository root to create it. Then run this block there; it keeps the other server settings and does not print the cookie:

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

Stop the current server and start it again from the repository root so it reloads both files:

```powershell
python .\gemini_web2api.py
```

Then restart OpenCode and select `gemini-4-argon`. Keep `gemini-auth.json` private; it is already ignored by Git. The cookie grants only the access the Google account's plan permits.

## Linux/WSL: apply it in `gemini-web2api`

Move the exported file into the project:

```bash
cd /path/to/gemini-web2api

WIN_HOME=$(wslpath "$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath(\"UserProfile\")' | tr -d '\r')")
cp "$WIN_HOME/Downloads/gemini-auth.json" ./gemini-auth.json
chmod 600 gemini-auth.json
```

Update `config.json`:

```bash
cd /path/to/gemini-web2api

AUTH_FILE="$(pwd)/gemini-auth.json"
tmp=$(mktemp)

jq \
  --arg auth_file "$AUTH_FILE" \
  --slurpfile auth "$AUTH_FILE" \
  '
    .cookie_file = $auth_file
    | .auth_user = $auth[0].auth_user
    | .xsrf_token = $auth[0].xsrf_token
    | if (($auth[0].gemini_bl // "") | length) > 0
      then .gemini_bl = $auth[0].gemini_bl
      else .
      end
  ' config.json > "$tmp" &&
mv "$tmp" config.json

chmod 600 config.json
```

Quick check:

```bash
jq '{
  cookie_file,
  auth_user,
  xsrf_token_set: ((.xsrf_token // "") | length > 0),
  gemini_bl_set: ((.gemini_bl // "") | length > 0)
}' config.json
```

## Restart and test

```bash
systemctl --user restart gemini-proxy
```

```bash
curl -sS http://127.0.0.1:10012/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "gemini-3.1-pro-preview",
    "messages": [
      {
        "role": "user",
        "content": "Reply exactly with: authenticated-ok"
      }
    ]
  }' | jq
```

## Keep it secret

`gemini-auth.json` contains a real Google session. Do not share it, print it, or commit it to Git.
