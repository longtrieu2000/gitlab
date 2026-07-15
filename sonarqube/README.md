# SonarQube Community Build - Production Deployment

Triển khai [SonarQube Community Build](https://www.sonarqube.org/) sử dụng **PostgreSQL 16** và **Nginx** để terminate TLS/SSL (Let's Encrypt / Self-Signed). Cấu trúc tương tự như dự án Vault.

---

## Yêu cầu hệ thống

| Resource | Tối thiểu | Khuyến nghị |
|---|---|---|
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 8 GB+ (Elasticsearch cần nhiều RAM) |
| Disk | 20 GB | 50 GB+ (tùy thuộc vào số lượng project scan) |
| Docker | 20.10+ | Latest |
| Docker Compose | v2.3+ | Latest |
| Domain | Cần DNS trỏ về server | - |

> [!IMPORTANT]
> **Yêu cầu quan trọng của Elasticsearch:**
> Elasticsearch tích hợp trong SonarQube yêu cầu tham số kernel `vm.max_map_count` trên host tối thiểu là `262144`.
> 
> Chạy các lệnh sau trên host trước khi start container:
> ```bash
> # Cấu hình tức thời
> sudo sysctl -w vm.max_map_count=524288
> 
> # Cấu hình persistent qua các lần reboot
> echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
> ```

---

## Quick Start

```bash
# 1. Di chuyển vào thư mục sonarqube
cd sonarqube/

# 2. Copy file config .env và chỉnh sửa mật khẩu/cấu hình nếu cần
cp .env.default .env
vim .env

# 3. Yêu cầu chứng chỉ Let's Encrypt (nếu dùng SSL_TYPE=letsencrypt)
sudo apt update && sudo apt install -y certbot
sudo certbot certonly --manual --preferred-challenges dns -d sonarqube.cloudsb.space

# 4. Khởi động hệ thống (sẽ tự động chạy script ssl để import/sinh cert và khởi chạy docker compose)
make up

# 5. Truy cập SonarQube
# URL: https://sonarqube.cloudsb.space:9000
# User mặc định: admin
# Password mặc định: admin (yêu cầu đổi ngay lần đăng nhập đầu tiên)
```

---

## Cấu trúc thư mục

```
sonarqube/
├── .env.default              # Biến cấu hình mặc định
├── .gitignore
├── makefile                  # Automation commands
├── README.md                 # Tài liệu hướng dẫn
├── docker-compose.yml        # Docker compose chứa db, sonarqube, nginx
├── nginx/
│   └── templates/
│       └── default.conf.template  # Cấu hình proxy Nginx (sử dụng envsubst)
├── scripts/
│   ├── generate-ssl.sh       # Sinh self-signed cert dự phòng
│   ├── setup-letsencrypt.sh  # Import Let's Encrypt cert từ thư mục certbot
│   └── renew-cert.sh         # Renew cert & reload Nginx
└── ssl/                      # ← Chứa certificate (sẽ tự sinh/import)
    ├── fullchain.pem
    └── privkey.pem
```

---

## Lệnh Makefile

| Lệnh | Mô tả |
|---|---|
| `make up` | Sinh cert (nếu chưa có) + khởi động SonarQube |
| `make down` | Tắt SonarQube |
| `make restart` | Khởi động lại các container |
| `make logs` | Xem logs thời gian thực |
| `make ps` | Xem trạng thái các container |
| `make ssl` | Sinh/import SSL cert |
| `make ssl-renew` | Gia hạn cert (force) |
| `make bash` | Shell vào container SonarQube |
| `make db-bash` | Shell vào container PostgreSQL |

---

## Cấu hình Let's Encrypt chi tiết (DNS Challenge)

Cách lấy certificate thông qua DNS Challenge mà không cần phải mở port 80/443 ra internet trong quá trình xác thực:

1. Chạy lệnh:
   ```bash
   sudo certbot certonly --manual --preferred-challenges dns -d sonarqube.cloudsb.space
   ```
2. Certbot sẽ in ra một giá trị TXT record ví dụ:
   - **Host/Name**: `_acme-challenge.sonarqube.cloudsb.space`
   - **Value**: `xYz1234567890-AbCdEf...`
3. Truy cập vào trình quản lý DNS của domain `cloudsb.space`, thêm bản ghi TXT tương ứng.
4. Chờ 1-2 phút để bản ghi lan truyền (kiểm tra bằng: `dig -t txt _acme-challenge.sonarqube.cloudsb.space`), sau đó nhấn Enter tại màn hình Certbot.
5. Sau khi thành công, chạy `make up` để script tự động import cert từ `/etc/letsencrypt/live/sonarqube.cloudsb.space` vào thư mục `./ssl/`.

---

## Tự động gia hạn SSL (Cronjob)

Thiết lập cronjob trên host chạy mỗi 60 ngày để tự động gia hạn chứng chỉ Let's Encrypt và reload Nginx:

```bash
# Mở crontab
sudo crontab -e

# Thêm cấu hình sau (chạy vào 3h sáng ngày 1 mỗi 2 tháng)
0 3 1 */2 * cd /home/longth1/workspace/gitlab/sonarqube && bash scripts/renew-cert.sh >> /var/log/sonarqube-cert-renew.log 2>&1
```

---

## Tích hợp GitLab CI/CD (Quét Code Tự Động)

Để tích hợp SonarQube với GitLab CI/CD, bạn cần:
1. Truy cập vào SonarQube UI (`https://sonarqube.cloudsb.space:9000`), vào **My Account** → **Security** → **Generate Token** (chọn loại **Global Analysis Token** hoặc **Project Analysis Token**).
2. Lưu token này vào biến CI/CD của GitLab (ở Settings → CI/CD → Variables của repo):
   - Key: `SONAR_TOKEN`
   - Value: `<token_vừa_tạo>`
3. Tạo biến `SONAR_HOST_URL` trong GitLab Variables:
   - Key: `SONAR_HOST_URL`
   - Value: `https://sonarqube.cloudsb.space:9000`
4. Cấu hình file `.gitlab-ci.yml` mẫu trong repo để chạy scan:

```yaml
sonarqube-check:
  stage: test
  image: 
    name: sonarsource/sonar-scanner-cli:latest
    entrypoint: [""]
  variables:
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"  # Cache scan results
    GIT_DEPTH: "0"  # Hướng dẫn quét toàn bộ lịch sử git commit (rất quan trọng)
  cache:
    key: "${CI_COMMIT_REF_SLUG}"
    paths:
      - .sonar/cache
  script:
    - sonar-scanner
  allow_failure: true
  only:
    - merge_requests
    - master
    - main
```

Tạo file `sonar-project.properties` trong thư mục gốc của repo gitlab để định nghĩa cấu hình quét:

```properties
sonar.projectKey=my-project-key
sonar.projectName=My Project Name
sonar.sources=.
sonar.sourceEncoding=UTF-8
```
