# gemini-web2api

<p align="center">
  <img src="logo.png" width="200" alt="Logo gemini-web2api">
</p>

[English](README.md)

Chuyển giao diện web Google Gemini thành API tương thích OpenAI. Miễn phí, đa nền tảng, chạy bằng một file.

## Tính năng

- **API key tùy chọn**: không xác thực khi `api_keys` rỗng; nếu cấu hình, hỗ trợ Bearer token kiểu OpenAI.
- **Tương thích OpenAI**: thay thế trực tiếp các endpoint `/v1/chat/completions` và `/v1/models`.
- **Gọi công cụ**: hỗ trợ function calling theo định dạng OpenAI.
- **Nhiều model**: Gemini 4 Argon, 3.8 Flash, 3.6 Flash, 3.5 Flash-Lite, 3.1 Pro Preview và Auto.
- **Mức độ suy luận**: điều chỉnh bằng hậu tố `@think=N` (0 sâu nhất, 4 nông nhất).
- **Tìm kiếm web**: dùng khả năng tìm kiếm tích hợp của Gemini.
- **Đa nền tảng**: Python thuần; `httpx` là thư viện tùy chọn để dùng streaming.
- **Streaming**: hỗ trợ SSE qua `httpx`.
- **Codex CLI**: hỗ trợ Responses API (`/v1/responses`) cho OpenAI Codex.
- **OpenCode**: cấu hình custom provider tương thích OpenAI qua `/v1/chat/completions`.
- **Claude Code**: hỗ trợ Anthropic Messages API (`/v1/messages`), tool call và SSE.
- **Gemini CLI**: hỗ trợ API gốc của Google (`/v1beta/models`).

## Bắt đầu nhanh

```bash
pip install httpx
python gemini_web2api.py
```

Server chạy tại `http://localhost:8081/v1`.

### Windows: cài nhanh các ứng dụng bằng một lệnh

Mở PowerShell tại thư mục repository rồi chạy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Script tự cài `httpx` nếu máy chưa có và tạo/cập nhật cấu hình server cùng các
client. OpenCode mặc định chọn **GW - Gemini 4 Argon**; ứng dụng ChatGPT/Codex
và extension Claude Code trong VS Code dùng `gemini-3.8-flash`. Argon cần tài
khoản Gemini đủ điều kiện và cookie. Server chạy ẩn trên `127.0.0.1`. Chạy xong,
đóng rồi mở lại OpenCode, ứng dụng ChatGPT/Codex và VS Code. Cần cài sẵn
extension Claude Code trong VS Code. Phần Claude cấu hình extension VS Code,
không cấu hình ứng dụng Claude Desktop.

Cấu hình client hiện có được gộp và sao lưu tại
`%LOCALAPPDATA%\Gemini Web2API\backups`. API key được tạo trên máy, lưu trong
`config.json` đã được Git ignore và các file cấu hình client. Server chạy trong
phiên Windows hiện tại; sau khi khởi động lại Windows, chạy lại lệnh setup.
Log nằm tại `%LOCALAPPDATA%\Gemini Web2API\server.log` và `server-error.log`.

## Cấu hình client

### Cherry Studio / ChatBox / client tương thích OpenAI

| Trường | Giá trị |
|--------|---------|
| Base URL | `http://localhost:8081/v1` |
| API Key | Một giá trị trong `api_keys` của `config.json`; nhập giá trị bất kỳ nếu chưa bật xác thực |
| Model | `gemini-3.8-flash` |

### Gửi request bằng curl

```bash
curl http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-key" \
  -d '{"model":"gemini-3.8-flash","messages":[{"role":"user","content":"Xin chào!"}]}'
```

Trên PowerShell, dùng `curl.exe` cùng `--%` để tránh PowerShell diễn giải lại JSON:

```powershell
curl.exe --% http://127.0.0.1:8081/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer sk-your-key" -d "{\"model\":\"gemini-3.8-flash\",\"messages\":[{\"role\":\"user\",\"content\":\"Xin chào!\"}]}"
```

### OpenAI Python SDK

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8081/v1", api_key="sk-your-key")
resp = client.chat.completions.create(
    model="gemini-3.8-flash@think=0",
    messages=[{"role": "user", "content": "Giải thích điện toán lượng tử"}]
)
print(resp.choices[0].message.content)
```

### OpenCode

Thêm cấu hình provider này vào `opencode.json`, rồi đặt `GEMINI_WEB2API_API_KEY`
bằng một key trong `config.json`. Nếu dùng Cloudflare Worker, thay URL bằng địa chỉ
Worker của bạn.

Trong PowerShell, đặt key cho phiên terminal hiện tại:

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
        "gemini-4-argon": { "name": "GW - Gemini 4 Argon" },
        "gemini-3.8-flash": { "name": "GW - Gemini 3.8 Flash" }
      }
    }
  }
}
```

Nếu server không bật xác thực API key, xóa trường `apiKey`.

### Claude Code

Trong PowerShell, trỏ Claude Code đến endpoint Anthropic và chọn một model Gemini:

```powershell
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8081"
$env:ANTHROPIC_AUTH_TOKEN = "sk-your-key"
claude --model gemini-3.8-flash
```

Khi dùng Cloudflare Worker, đặt `ANTHROPIC_BASE_URL` thành domain Worker. Claude Code
gửi request đến `/v1/messages`; server chuyển đổi Messages API, tool call và sự kiện
streaming sang định dạng Gemini Web.

### Gemini CLI

```bash
export GEMINI_API_KEY=none
export GOOGLE_GEMINI_BASE_URL=http://localhost:8081
gemini
```

Các endpoint API Google được hỗ trợ:
- `GET /v1beta/models` — liệt kê model
- `POST /v1beta/models/{model}:generateContent` — tạo nội dung không streaming
- `POST /v1beta/models/{model}:streamGenerateContent` — tạo nội dung dạng SSE

## Danh sách model

| Model ID | Cấp model | Ghi chú |
|----------|-----------|---------|
| `gemini-4-argon` | Argon | Cần tài khoản và gói Google AI đủ điều kiện |
| `gemini-3.8-flash` | Flash | Model Gemini Flash hiện tại |
| `gemini-3.6-flash` | Flash | Thế hệ Flash trước |
| `gemini-3.5-flash-lite` | Flash-Lite | Nhanh, tiết kiệm tài nguyên |
| `gemini-3.1-pro-preview` | Pro | Bản preview; cần tài khoản đủ điều kiện |
| `gemini-auto` | Auto | Để Gemini tự chọn model |

Thêm `@think=N` vào cuối tên model để điều chỉnh mức suy luận:

```
gemini-3.8-flash@think=0   # sâu nhất
gemini-3.8-flash@think=2   # trung bình
gemini-3.8-flash@think=4   # tự động/nông nhất
```

## Cookie cho Pro và Argon

Khả năng dùng Pro và Argon phụ thuộc vào gói Google AI và tài khoản đang đăng nhập. Repository có sẵn extension Chrome/Edge để xuất phiên Gemini và metadata ngay trên máy.

### Setup nhanh bằng Gemini Cookie Sync

1. Mở `chrome://extensions` trên Chrome hoặc `edge://extensions` trên Edge, bật **Developer mode**, rồi chọn **Load unpacked**.
2. Chọn thư mục `gemini-cookie-sync-extension` trong repository này.
3. Mở [Gemini](https://gemini.google.com/app), đăng nhập tài khoản có quyền dùng model rồi tải lại trang.
4. Mở extension **Gemini Cookie Sync**, bấm **Inspect session**. Khi extension báo session và XSRF đã sẵn sàng, bấm **Export gemini-auth.json** và lưu thành `gemini-auth.json` vào thư mục gốc repository.

Extension đọc phiên Google hiện tại và metadata của trang Gemini trong trình duyệt, sau đó tải JSON về máy; không gửi phiên đăng nhập lên server. `gemini-auth.json` chứa thông tin đăng nhập và đã được Git bỏ qua. Không dán hoặc chia sẻ file này.

Mở PowerShell tại thư mục gốc repository, chạy `setup.ps1` một lần nếu chưa có `config.json`, rồi chạy lệnh dưới đây để gộp dữ liệu extension mà vẫn giữ cài đặt server khác:

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

Khởi động lại server để nạp lại hai file, rồi mở lại OpenCode. Model mặc định sẽ là **GW - Gemini 4 Argon**. Nếu chạy server thủ công, mở PowerShell tại thư mục repository rồi chạy `python gemini_web2api.py`. Xem đầy đủ các bước tại [`gemini-cookie-sync-extension/SETUP.md`](gemini-cookie-sync-extension/SETUP.md). Phiên đăng nhập hợp lệ không tự cấp quyền cho model mà gói Google của tài khoản không hỗ trợ.

Nếu **Inspect session** báo thiếu XSRF, tải lại Gemini rồi kiểm tra lại. Nếu request vẫn trả HTTP 400 có lỗi `xsrf`, xuất lại file rồi khởi động lại server. Extension xuất `auth_user`, `xsrf_token` và `gemini_bl` cùng cookie.

## Cấu hình

Tạo file `config.json` trong cùng thư mục:

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

Đặt `temporary_chats` thành `true` để dùng cuộc trò chuyện tạm thời thay vì lưu lịch sử vào tài khoản. Nếu `api_keys` là `[]`, server không xác thực API key; nếu có key, endpoint `/v1/*` yêu cầu `Authorization: Bearer <key>` hoặc `x-api-key: <key>`.

## Docker

```bash
cp config.example.json config.json
docker build -t gemini-web2api .
docker run -d --name gemini-web2api -p 8081:8081 -v ./config.json:/app/config.json gemini-web2api
```

Hoặc dùng Docker Compose:

```bash
cp config.example.json config.json
docker compose up -d
```

Để mount file cookie, thêm `-v ./cookie.txt:/app/cookie.txt` vào lệnh `docker run` và đặt `"cookie_file": "/app/cookie.txt"` trong cấu hình.

> Nếu response rỗng (`content: null`) với mạng bridge mặc định, hãy thử host networking (`docker run --network host ...` hoặc `network_mode: host` trong compose). Gemini upstream có thể từ chối một số dải IP NAT của Docker.

## Cloudflare Workers

Xem [hướng dẫn triển khai Cloudflare Workers](cloudflare/README.MD) để cấu hình Worker, cookie và biến môi trường.

## Proxy

Nếu không thể truy cập trực tiếp `gemini.google.com`, hãy cấu hình proxy bằng một trong các cách sau:

```bash
python gemini_web2api.py --proxy http://127.0.0.1:7890
```

Hoặc trong `config.json`:

```json
{"proxy": "http://127.0.0.1:7890"}
```

Hoặc đặt biến môi trường:

```bash
export HTTPS_PROXY=http://127.0.0.1:7890
python gemini_web2api.py
```

Tương thích với Clash, V2Ray, Shadowsocks và các HTTP proxy khác.

## Gọi công cụ

```python
resp = client.chat.completions.create(
    model="gemini-3.8-flash",
    messages=[{"role": "user", "content": "Thời tiết ở Tokyo thế nào?"}],
    tools=[{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Lấy thời tiết của một thành phố",
            "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}
        }
    }]
)
```

## Đầu vào hình ảnh

Chat Completions và Responses API hỗ trợ tin nhắn đa phương thức. Có thể dùng URL ảnh HTTP(S) hoặc data URL base64:

```python
resp = client.chat.completions.create(
    model="gemini-3.8-flash",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "Mô tả hình ảnh này"},
            {"type": "image_url", "image_url": {"url": "https://example.com/image.png"}}
        ]
    }]
)
```

## Giới hạn và yêu cầu

- Tải ảnh có thể cần cookie. Nếu tải ẩn danh thất bại, hãy cấu hình cookie Gemini.
- Việc định tuyến Pro và Argon phụ thuộc vào gói và model đang khả dụng cho tài khoản.
- Mỗi request là một lượt độc lập; lịch sử nhiều lượt được mô phỏng bằng cách đưa các tin nhắn trước vào prompt.
- Google có thể giới hạn request dày đặc. Server tự thử lại, nhưng tải cao kéo dài vẫn có thể bị chặn.
- Cần Python 3.8 trở lên và có thể truy cập `gemini.google.com` (một số khu vực có thể cần proxy/VPN).
- `httpx` (`pip install httpx`) được dùng cho streaming.

## Cách hoạt động

Công cụ phân tích ngược giao thức StreamGenerate của Google Gemini Web, gửi request đến endpoint mà Gemini Web sử dụng và chuyển đổi giữa định dạng OpenAI với định dạng gần protobuf nội bộ của Gemini. Việc chọn model được điều khiển bởi trường `[79]` trong payload, ánh xạ từ enum `MODE_CATEGORY` trong JavaScript của Gemini.

## Ghi nhận và giấy phép

- Lấy cảm hứng từ hệ sinh thái proxy API mã nguồn mở.
- Năng lực agent trong quá trình phát triển được cung cấp bởi [GenericAgent](https://github.com/lsdefine/GenericAgent).
- Cộng đồng [LinuxDo](https://linux.do/).
- MIT
