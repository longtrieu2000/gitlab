# Harbor Container Registry

Private Docker Registry sử dụng [Harbor](https://goharbor.io/) v2.15.1 với SSL self-signed.

## Yêu cầu hệ thống

| Resource | Tối thiểu | Khuyến nghị |
|---|---|---|
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 8 GB |
| Disk | 40 GB | 160 GB |
| Docker | 20.10+ | Latest |
| Docker Compose | v2.3+ | Latest |

## Quick Start

```bash
# 1. Copy env và chỉnh sửa
cp .env.default .env
vim .env   # thay HARBOR_HOST, HARBOR_ADMIN_PASSWORD, HARBOR_DB_PASSWORD

# 2. Cài đặt (sinh cert + tải Harbor + deploy)
make install

# 3. Truy cập
# https://<HARBOR_HOST>
# User: admin / Password: từ HARBOR_ADMIN_PASSWORD
```

## Cấu trúc thư mục

```
harbor/
├── .env.default          # Biến cấu hình
├── .gitignore
├── makefile              # Lệnh quản lý
├── README.md
├── scripts/
│   ├── generate-ssl.sh   # Sinh CA + Server cert
│   ├── install.sh        # Tải + cấu hình + deploy Harbor
│   └── uninstall.sh      # Gỡ cài đặt
├── ssl/                  # ← Tự sinh khi make install
│   ├── ca.crt            #    CA certificate
│   ├── ca.key            #    CA private key
│   ├── <IP>.crt          #    Server certificate
│   ├── <IP>.key          #    Server private key
│   └── <IP>.cert         #    Docker daemon format
└── harbor-installer/     # ← Tự tải khi make install
    ├── harbor.yml        #    Harbor config (auto-generated)
    ├── docker-compose.yml
    └── ...
```

## Lệnh Makefile

| Lệnh | Mô tả |
|---|---|
| `make install` | Cài đặt từ đầu (cert + download + deploy) |
| `make up` | Khởi động Harbor |
| `make down` | Tắt Harbor |
| `make restart` | Restart |
| `make logs` | Xem logs |
| `make ps` | Trạng thái containers |
| `make status` | Health check API |
| `make ssl` | Sinh lại SSL cert |
| `make docker-trust` | Cấu hình Docker trust cert |
| `make uninstall` | Gỡ cài đặt + xoá data |

## Cấu hình Docker Client (máy khác)

Để push/pull image từ máy khác, cần trust CA cert:

```bash
# Copy ca.crt từ Harbor server
scp user@<harbor-host>:~/harbor/ssl/ca.crt /tmp/harbor-ca.crt

# Trust cho Docker daemon
sudo mkdir -p /etc/docker/certs.d/<HARBOR_HOST>
sudo cp /tmp/harbor-ca.crt /etc/docker/certs.d/<HARBOR_HOST>/ca.crt
sudo systemctl restart docker

# Login
docker login <HARBOR_HOST>

# Push
docker tag myimage <HARBOR_HOST>/library/myimage:latest
docker push <HARBOR_HOST>/library/myimage:latest
```

## Tích hợp với GitLab CI/CD

Trong `.gitlab-ci.yml`:

```yaml
variables:
  HARBOR_REGISTRY: "<HARBOR_HOST>"
  IMAGE_NAME: "${HARBOR_REGISTRY}/library/${CI_PROJECT_NAME}"

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u admin -p $HARBOR_PASSWORD $HARBOR_REGISTRY
  script:
    - docker build -t ${IMAGE_NAME}:${CI_COMMIT_SHA} .
    - docker push ${IMAGE_NAME}:${CI_COMMIT_SHA}
```
