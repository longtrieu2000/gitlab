# GitLab Runner (Self-Signed SSL)

Runner deploy riêng trên máy runner host, kết nối tới GitLab Server qua **HTTPS** (self-signed cert).

## Chuẩn bị

**Bắt buộc**: Copy cert từ GitLab Server trước khi chạy:

```bash
mkdir -p ssl
scp user@<gitlab-host>:~/gitlab/ssl/<IP>.crt ./ssl/
```

## Quick Start

```bash
# 1. Copy env file và chỉnh sửa
cp .env.default .env
vim .env  # điền REGISTRATION_TOKEN, GITLAB_HOST, GITLAB_URL

# 2. Copy cert (xem phần Chuẩn bị ở trên)

# 3. Khởi động (auto-check cert)
make up

# 4. Đăng ký runner
make register

# 5. Kiểm tra
make list
```

## Lấy Registration Token

1. Đăng nhập GitLab: `https://<GITLAB_HOST>:3080`
2. **Admin Area → CI/CD → Runners → New instance runner**
3. Copy token (dạng `glrt-...`)
4. Paste vào `REGISTRATION_TOKEN` trong `.env`

## Makefile Commands

| Command | Mô tả |
|---|---|
| `make up` | Khởi động (auto check cert) |
| `make down` | Tắt runner |
| `make logs` | Xem logs realtime |
| `make register` | Đăng ký (Docker executor + trust cert) |
| `make register-shell` | Đăng ký (Shell executor + trust cert) |
| `make unregister` | Xoá tất cả đăng ký |
| `make list` | Liệt kê runners |
| `make check-cert` | Kiểm tra cert đã copy chưa |
