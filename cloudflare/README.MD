# Gemini Web2API — Hướng dẫn triển khai Cloudflare Workers

## Giới thiệu

Gemini Web2API là proxy chạy trên Cloudflare Workers, chuyển giao diện web Google Gemini thành API tương thích OpenAI. Không cần tự quản lý máy chủ; API key có thể bật hoặc tắt tùy cấu hình.

### Tính năng chính

- Triển khai trên gói Cloudflare Workers miễn phí.
- Phân phối qua mạng lưới edge toàn cầu của Cloudflare.
- Tương thích với `/v1/chat/completions` và `/v1/models`.
- Streaming SSE.
- Luân phiên dấu vân tay trình duyệt, ngôn ngữ và nhiều cookie.
- Tách cấu hình theo request để tránh các request đồng thời ghi đè cấu hình của nhau.
- Hỗ trợ gọi công cụ theo định dạng OpenAI Function Calling.
- Dùng được với OpenCode qua OpenAI-compatible provider.
- Dùng được với Claude Code qua Anthropic Messages API (`/v1/messages`).

### Trường hợp sử dụng

- Kết nối NextChat, Cherry Studio, ChatBox và các client tương thích OpenAI.
- Kết nối OpenCode và Claude Code.
- Dùng Gemini làm backend cho WorkBuddy hoặc công cụ tương tự.
- Học tập, nghiên cứu và các dự án cá nhân quy mô nhỏ.

## Triển khai nhanh

### 1. Đăng nhập Cloudflare

1. Mở [Cloudflare Dashboard](https://dash.cloudflare.com).
2. Đăng nhập hoặc tạo tài khoản miễn phí.
3. Mở mục **Workers & Pages** ở thanh bên.

### 2. Tạo Worker

1. Chọn **Create application** → **Create Worker**.
2. Đặt tên cho Worker, ví dụ `api`.
3. Chọn **Deploy**, sau đó **Edit code**.
4. Xóa mã mặc định và dán toàn bộ mã nguồn của dự án vào trình soạn thảo.
5. Chọn **Save and deploy**.

### 3. Lấy địa chỉ API

Sau khi triển khai, địa chỉ thường có dạng:

```
https://<ten-worker>.<ten-tai-khoan>.workers.dev
```

Ví dụ: `https://api.geminai.workers.dev`.

### 4. Kiểm tra

Mở endpoint sau trong trình duyệt:

```
https://<ten-worker>.workers.dev/health
```

Nếu triển khai thành công, server trả về JSON tương tự:

```json
{
  "status": "ok",
  "version": "1.5.0-cf-multifingerprint",
  "platform": "Cloudflare Workers",
  "models": ["gemini-4-argon", "gemini-3.8-flash", "..."],
  "hasCookie": false,
  "hasSapisid": false
}
```

## Cấu hình client

### NextChat

| Thiết lập | Giá trị |
|-----------|---------|
| Loại API | OpenAI |
| Base URL | `https://<ten-worker>.workers.dev/v1` |
| API Key | `sk-gemini` (mặc định) |
| Model | `gemini-3.8-flash` |

### Cherry Studio

| Thiết lập | Giá trị |
|-----------|---------|
| API URL | `https://<ten-worker>.workers.dev/v1` |
| API Key | `sk-gemini` |
| Model | `gemini-3.8-flash` |

### ChatBox

| Thiết lập | Giá trị |
|-----------|---------|
| Chế độ API | OpenAI API |
| API domain | `https://<ten-worker>.workers.dev` |
| API path | `/v1/chat/completions` |
| API Key | `sk-gemini` |

### OpenCode

Thêm provider này vào `opencode.json` và thay domain Worker của bạn:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "gemini-web2api/gemini-3.8-flash",
  "provider": {
    "gemini-web2api": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Gemini Web2API",
      "options": {
        "baseURL": "https://<ten-worker>.workers.dev/v1",
        "apiKey": "sk-gemini"
      },
      "models": {
        "gemini-3.8-flash": { "name": "Gemini 3.8 Flash" }
      }
    }
  }
}
```

### Claude Code

Chạy bằng PowerShell, thay URL bằng domain Worker của bạn:

```powershell
$env:ANTHROPIC_BASE_URL = "https://<ten-worker>.workers.dev"
$env:ANTHROPIC_AUTH_TOKEN = "sk-gemini"
claude --model gemini-3.8-flash
```

Claude Code sẽ gọi endpoint `/v1/messages` của Worker.

### Thử bằng curl

Request không streaming:

```bash
curl https://<ten-worker>.workers.dev/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-gemini" \
  -d '{
    "model": "gemini-3.8-flash",
    "messages": [{"role": "user", "content": "Xin chào"}],
    "stream": false
  }'
```

Request streaming:

```bash
curl -N https://<ten-worker>.workers.dev/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-gemini" \
  -d '{
    "model": "gemini-3.8-flash",
    "messages": [{"role": "user", "content": "Kể một câu chuyện"}],
    "stream": true
  }'
```

## Biến môi trường tùy chọn

Cấu hình tại **Cloudflare Dashboard → Workers → Worker của bạn → Settings → Variables and Secrets**.

### Xác thực

| Tên | Mô tả | Ví dụ |
|-----|-------|-------|
| `COOKIE_STRING` | Cookie Gemini; phân cách nhiều tài khoản bằng `\|` | `cookie1\|cookie2` |
| `SAPISID` | Giá trị SAPISID; có thể phân cách nhiều tài khoản bằng `\|` | `sapisid1\|sapisid2` |
| `API_KEYS` | Danh sách API key dạng JSON | `["sk-gemini", "my-key"]` |

### Gemini

| Tên | Mô tả | Ví dụ |
|-----|-------|-------|
| `GEMINI_BL` | Nhãn build Gemini; cập nhật nếu gặp HTTP 405 | `boq_assistant-bard-web-server_20260716.08_p0` |
| `DEFAULT_MODEL` | Model mặc định | `gemini-3.8-flash` |
| `AUTH_USER` | Chỉ số tài khoản | `0` |

### Hiệu năng

| Tên | Mô tả | Mặc định |
|-----|-------|----------|
| `RETRY_ATTEMPTS` | Số lần thử lại | `3` |
| `RETRY_DELAY_SEC` | Thời gian chờ giữa các lần thử (giây) | `2` |
| `REQUEST_TIMEOUT_SEC` | Thời gian chờ request (giây) | `28` |
| `FINGERPRINT_JITTER_MS` | Độ trễ ngẫu nhiên tối đa (ms) | `1500` |
| `RATE_LIMIT_MAX` | Số request tối đa trong cửa sổ giới hạn | `3000` |
| `RATE_LIMIT_WINDOW` | Cửa sổ giới hạn (giây) | `60` |

## Lấy cookie Gemini

### Vì sao cần cookie?

Request ẩn danh có thể dễ bị giới hạn tần suất (HTTP 429). Cookie hợp lệ có thể giúp request ổn định hơn và cho phép sử dụng các cấp model phụ thuộc tài khoản. Quyền dùng Pro hoặc Argon vẫn tùy theo gói Google AI của tài khoản.

### Các bước lấy cookie

1. Mở Chrome hoặc Edge.
2. Truy cập [gemini.google.com/app](https://gemini.google.com/app) và đăng nhập.
3. Nhấn **F12** để mở DevTools.
4. Chọn thẻ **Application**.
5. Trong phần **Cookies**, mở `https://gemini.google.com`.
6. Sao chép các giá trị `__Secure-1PSID`, `__Secure-3PSID` và `SAPISID`.
7. Ghép thành một chuỗi cookie:

```
__Secure-1PSID=your_value; __Secure-3PSID=your_value; SAPISID=your_value
```

### Cấu hình nhiều tài khoản

Dùng dấu `|` để phân cách cookie của nhiều tài khoản:

```
COOKIE_STRING="cookie_account_1|cookie_account_2|cookie_account_3"
SAPISID="sapisid_1|sapisid_2|sapisid_3"
```

Mỗi request sẽ chọn một bộ thông tin xác thực để gửi.

## Cập nhật phiên bản BL

Lỗi `HTTP 405: Method Not Allowed` có thể cho biết build Gemini Web đã thay đổi. Để cập nhật:

1. Mở [gemini.google.com/app](https://gemini.google.com/app).
2. Nhấn **F12** → **Network**.
3. Tìm `boq_assistant` trong URL của request.
4. Sao chép nhãn build mới, ví dụ:

```
boq_assistant-bard-web-server_20260730.02_p0
```

5. Cập nhật biến `GEMINI_BL` hoặc cấu hình `geminiBl` trong mã Worker.

## Luân phiên dấu vân tay

Worker có thể luân phiên một số header và thêm độ trễ ngẫu nhiên trước khi gửi request:

| Loại | Số lượng/phạm vi | Mô tả |
|------|------------------|-------|
| User-Agent | 8 mẫu | Chọn ngẫu nhiên có trọng số |
| Accept-Language | 6 mẫu | Luân phiên ngôn ngữ |
| Sec-Ch-Ua | 3 mẫu | Header phiên bản Chrome, chỉ dùng với Chrome User-Agent |
| Độ trễ ngẫu nhiên | 0–1500 ms | Có thể điều chỉnh bằng `FINGERPRINT_JITTER_MS` |

## Khuyến nghị bảo mật

1. Thay API key mặc định `sk-gemini` bằng key riêng.
2. Điều chỉnh giới hạn request `RATE_LIMIT_MAX` theo nhu cầu.
3. Cookie Google có thời hạn; cập nhật khi hết hạn.
4. Không chia sẻ cookie vì cookie có thể cấp quyền truy cập tài khoản Google.

## Câu hỏi thường gặp

### `empty response from server`

**Nguyên nhân:** client có thể xử lý streaming SSE không đúng.

**Cách xử lý:** cập nhật Worker lên phiên bản mới nhất và kiểm tra lại cấu hình streaming.

### `HTTP 429: Too Many Requests`

**Nguyên nhân:** Gemini giới hạn request; request ẩn danh thường bị giới hạn chặt hơn.

**Cách xử lý:** cấu hình cookie hợp lệ trong `COOKIE_STRING` và `SAPISID`.

### `HTTP 405: Method Not Allowed`

**Nguyên nhân:** nhãn build `GEMINI_BL` đã cũ.

**Cách xử lý:** cập nhật theo mục “Cập nhật phiên bản BL”.

### `invalid api key`

**Nguyên nhân:** API key của client không khớp.

**Cách xử lý:** kiểm tra client dùng key đã cấu hình; mặc định là `sk-gemini`.

### Request đồng thời trong WorkBuddy bị lẫn cấu hình

Phiên bản hiện tại tạo cấu hình riêng theo từng request để tránh chia sẻ trạng thái cấu hình giữa các request đồng thời.

## Danh sách model

| Model ID | Loại | Ghi chú |
|----------|------|---------|
| `gemini-4-argon` | ARGON | Cần tài khoản Google AI phù hợp; category 7 là giá trị suy luận |
| `gemini-3.8-flash` | FAST | Gemini Flash hiện tại |
| `gemini-3.6-flash` | FAST | Thế hệ Flash trước |
| `gemini-3.5-flash-lite` | FLASH_LITE | Nhanh, tiết kiệm tài nguyên |
| `gemini-3.1-pro-preview` | PRO | Bản preview; cần tài khoản phù hợp |
| `gemini-auto` | AUTO | Tự động chọn model |

Có thể thêm `@think=` để chọn mức suy luận của Gemini Web:

- `gemini-3.8-flash@think=4` — Flash, mức thấp.
- `gemini-3.8-flash@think=2` — Flash, mức trung bình.
- `gemini-3.8-flash@think=0` — Flash, mức cao.

## Nhật ký thay đổi

| Phiên bản | Ngày | Nội dung |
|-----------|------|----------|
| 1.5.0 | 2026-07-31 | Thêm luân phiên dấu vân tay, nhiều cookie và độ trễ ngẫu nhiên |
| 1.4.0 | 2026-07-30 | Sửa lỗi lẫn cấu hình khi chạy đồng thời và an toàn bộ nhớ cho giới hạn tần suất |
| 1.3.0 | 2026-07-29 | Sửa định dạng SSE và khả năng tương thích NextChat |
| 1.0.0 | 2026-07-16 | Bản đầu tiên, chuyển thể từ gemini-web2api v1.1.0 |

## Giấy phép

Worker này được chuyển thể từ dự án [gemini-web2api](https://github.com/Sophomoresty/gemini-web2api) và tuân theo giấy phép mã nguồn mở của dự án gốc.
