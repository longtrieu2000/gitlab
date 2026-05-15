# GitLab Runner

Runner được deploy riêng trên máy runner host, kết nối tới GitLab Server tại git host.

## Quick Start

```bash
# 1. Copy env file và chỉnh sửa token
cp .env.default .env
vim .env  # điền REGISTRATION_TOKEN, GITLAB_HOST

# 2. Khởi động
make up

# 3. Đăng ký runner
make register

# 4. Kiểm tra
make list
```

## Lấy Registration Token

### GitLab 18.x (New Runner Registration Flow)

1. Vào GitLab: **Admin > CI/CD > Runners** (hoặc **Project > Settings > CI/CD > Runners**)
2. Click **"New instance runner"** (hoặc **"New project runner"**)
3. Chọn platform **Linux**, thêm tags, mô tả
4. Click **"Create runner"**
5. Copy **runner authentication token** (bắt đầu bằng `glrt-...`)
6. Paste vào `REGISTRATION_TOKEN` trong file `.env`

## Makefile Commands

| Command | Mô tả |
|---|---|
| `make up` | Khởi động runner container |
| `make down` | Tắt runner |
| `make logs` | Xem logs realtime |
| `make register` | Đăng ký runner (Docker executor) |
| `make register-shell` | Đăng ký runner (Shell executor) |
| `make unregister` | Xoá tất cả đăng ký |
| `make list` | Liệt kê runners đã đăng ký |
