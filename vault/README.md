# HashiCorp Vault - Production Deployment

Secret management server sử dụng [HashiCorp Vault](https://www.vaultproject.io/) với **Integrated Raft Storage** và **TLS (Let's Encrypt)**.

## Tổng quan kiến trúc

```
┌─────────────────────────────────────────────┐
│              Vault Server                   │
│                                             │
│  ┌─────────┐    ┌──────────────────────┐    │
│  │  HTTPS   │───▶│   Vault Core          │    │
│  │  :8200   │    │                      │    │
│  └─────────┘    │  ┌────────────────┐  │    │
│                  │  │  Raft Storage  │  │    │
│  ┌─────────┐    │  │  (Persistent)  │  │    │
│  │ Cluster │───▶│  └────────────────┘  │    │
│  │  :8201   │    │                      │    │
│  └─────────┘    │  ┌────────────────┐  │    │
│                  │  │   TLS Certs    │  │    │
│                  │  │ (Let's Encrypt)│  │    │
│                  │  └────────────────┘  │    │
│                  └──────────────────────┘    │
└─────────────────────────────────────────────┘
```

## Yêu cầu hệ thống

| Resource | Tối thiểu | Khuyến nghị |
|---|---|---|
| CPU | 2 cores | 4 cores |
| RAM | 2 GB | 4 GB |
| Disk | 20 GB | 50 GB+ |
| Docker | 20.10+ | Latest |
| Docker Compose | v2.3+ | Latest |
| Domain | Cần DNS trỏ về server | - |

## Quick Start

```bash
# 1. Copy env và chỉnh sửa
cp .env.default .env
vim .env   # kiểm tra VAULT_HOST, SSL_TYPE, ports

# 2. Lấy chứng chỉ Let's Encrypt (chỉ lần đầu)
sudo apt update && sudo apt install -y certbot
sudo certbot certonly --manual --preferred-challenges dns -d vault.cloudsb.space

# 3. Cài đặt & khởi động
make up

# 4. Khởi tạo Vault (chỉ lần đầu)
make init

# 5. Unseal Vault (cần 3 trong 5 key)
make unseal   # chạy 3 lần, mỗi lần nhập 1 key khác nhau

# 6. Truy cập Web UI
# https://vault.cloudsb.space:8200
```

## Cấu trúc thư mục

```
vault/
├── .env.default              # Biến cấu hình
├── .gitignore
├── makefile                  # Lệnh quản lý
├── README.md
├── docker-compose.yml        # Docker Compose
├── config/
│   └── vault.hcl            # Vault server config
├── scripts/
│   ├── generate-ssl.sh       # Sinh self-signed cert
│   ├── setup-letsencrypt.sh  # Import Let's Encrypt cert
│   └── renew-cert.sh        # Auto-renew cert
├── ssl/                      # ← Tự sinh khi make ssl
│   ├── fullchain.pem        #    Certificate (full chain)
│   └── privkey.pem          #    Private key
└── vault-init-keys.json     # ← Tạo khi make init (LƯU AN TOÀN!)
```

## Lệnh Makefile

| Lệnh | Mô tả |
|---|---|
| `make up` | Sinh cert (nếu chưa có) + khởi động Vault |
| `make down` | Tắt Vault |
| `make restart` | Restart Vault |
| `make logs` | Xem logs |
| `make ps` | Trạng thái containers |
| `make status` | Kiểm tra Vault status (sealed/unsealed) |
| `make ssl` | Sinh/import SSL cert |
| `make ssl-renew` | Renew cert (force) |
| `make init` | Khởi tạo Vault lần đầu (tạo unseal keys) |
| `make unseal` | Unseal Vault (nhập 1 key mỗi lần, chạy 3 lần) |
| `make unseal-auto` | Auto-unseal bằng file init keys (chỉ cho dev) |
| `make snapshot` | Tạo Raft backup snapshot |
| `make restore` | Restore từ snapshot |
| `make bash` | Shell vào container Vault |

---

## Hướng dẫn Deploy Production chi tiết

### Bước 1: Chuẩn bị DNS

Đảm bảo domain `vault.cloudsb.space` đã có bản ghi DNS trỏ về IP server:

```bash
# Kiểm tra DNS
nslookup vault.cloudsb.space
# hoặc
dig vault.cloudsb.space +short
```

### Bước 2: Lấy chứng chỉ Let's Encrypt

```bash
# Cài certbot
sudo apt update && sudo apt install -y certbot

# Lấy cert bằng DNS challenge (không cần mở port 80)
sudo certbot certonly --manual --preferred-challenges dns -d vault.cloudsb.space
```

Certbot sẽ yêu cầu bạn tạo bản ghi **TXT** trên DNS:
- **Name**: `_acme-challenge.vault.cloudsb.space`
- **Value**: chuỗi do Certbot cung cấp

Chờ DNS propagate (1-5 phút), rồi nhấn Enter.

Cert sẽ được lưu tại: `/etc/letsencrypt/live/vault.cloudsb.space/`

### Bước 3: Cấu hình và khởi động

```bash
cd vault/

# Copy env
cp .env.default .env

# Kiểm tra cấu hình (mặc định đã đúng cho vault.cloudsb.space)
cat .env

# Khởi động (tự import cert + start container)
make up
```

### Bước 4: Khởi tạo Vault (chỉ lần đầu tiên)

```bash
make init
```

Output sẽ trả về JSON chứa:
- **5 Unseal Keys** (cần 3/5 để unseal)
- **1 Root Token** (đăng nhập admin)

```json
{
  "unseal_keys_b64": [
    "key1...",
    "key2...",
    "key3...",
    "key4...",
    "key5..."
  ],
  "root_token": "hvs.XXXXXXXXXXXX"
}
```

> ⚠️ **QUAN TRỌNG**: Lưu file `vault-init-keys.json` ở nơi an toàn (password manager, USB encrypted). Phân phối 5 key cho 5 người khác nhau. Xóa file khỏi server sau khi backup!

### Bước 5: Unseal Vault

Mỗi khi Vault khởi động lại, nó ở trạng thái **sealed** (khóa). Cần 3/5 key để unseal:

```bash
make unseal   # nhập key 1
make unseal   # nhập key 2
make unseal   # nhập key 3
```

Kiểm tra trạng thái:
```bash
make status
# Sealed: false  ← đã unseal thành công
```

### Bước 6: Truy cập Web UI

Mở trình duyệt: `https://vault.cloudsb.space:8200`

Đăng nhập bằng **Root Token** từ bước 4.

---

## Hướng dẫn sử dụng Vault trong Production

### 1. Cấu hình Vault CLI trên máy client

```bash
# Cài vault CLI
# Ubuntu/Debian:
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# Cấu hình endpoint
export VAULT_ADDR="https://vault.cloudsb.space:8200"

# Đăng nhập bằng root token (lần đầu)
vault login
# Token (will be hidden): <nhập root token>
```

### 2. Tạo Secret Engine (KV v2 - Key-Value)

```bash
# Bật KV v2 secret engine tại path "secret/"
vault secrets enable -path=secret kv-v2
```

### 3. Lưu trữ Secrets

```bash
# Lưu database credentials
vault kv put secret/database/postgres \
    username="gitlab" \
    password="super_secure_password" \
    host="172.23.1.16" \
    port="5432"

# Lưu API keys
vault kv put secret/api/cloudflare \
    api_token="cf-xxxxxxxxxxxx" \
    zone_id="zone-123456"

# Lưu Docker registry credentials
vault kv put secret/registry/harbor \
    username="admin" \
    password="Harbor12345" \
    url="https://172.23.1.17:3089"

# Đọc secret
vault kv get secret/database/postgres

# Đọc chỉ 1 field
vault kv get -field=password secret/database/postgres
```

### 4. Tạo Policies (phân quyền)

```bash
# Tạo policy cho CI/CD - chỉ đọc được secrets trong path secret/cicd/*
vault policy write cicd-readonly - <<EOF
path "secret/data/cicd/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/cicd/*" {
  capabilities = ["read", "list"]
}
EOF

# Tạo policy cho DBA - đọc/ghi database secrets
vault policy write dba - <<EOF
path "secret/data/database/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/database/*" {
  capabilities = ["read", "list"]
}
EOF

# Tạo policy cho admin - full access
vault policy write admin - <<EOF
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
```

### 5. Tạo Token cho ứng dụng / CI/CD

```bash
# Tạo token cho CI/CD pipeline (TTL 24h, tự renew được)
vault token create \
    -policy="cicd-readonly" \
    -ttl=24h \
    -renewable=true \
    -display-name="gitlab-cicd"

# Tạo token cho DBA (TTL 8h)
vault token create \
    -policy="dba" \
    -ttl=8h \
    -display-name="dba-team"
```

### 6. Tích hợp với GitLab CI/CD

**Cách 1: Dùng Vault Token trực tiếp**

Thêm biến `VAULT_TOKEN` vào GitLab CI/CD Variables (Settings → CI/CD → Variables):

```yaml
# .gitlab-ci.yml
variables:
  VAULT_ADDR: "https://vault.cloudsb.space:8200"

stages:
  - deploy

deploy:
  stage: deploy
  image: hashicorp/vault:latest
  script:
    # Đọc secret từ Vault
    - export DB_PASSWORD=$(vault kv get -field=password secret/cicd/database)
    - export API_KEY=$(vault kv get -field=api_token secret/cicd/cloudflare)
    # Sử dụng secret trong deployment
    - echo "Deploying with secrets..."
```

**Cách 2: Dùng GitLab Native Vault Integration (khuyến nghị)**

Trong GitLab Settings → CI/CD → Secrets:
1. Thêm Vault server URL: `https://vault.cloudsb.space:8200`
2. Cấu hình Auth method (JWT)
3. Sử dụng trong CI/CD:

```yaml
deploy:
  stage: deploy
  secrets:
    DATABASE_PASSWORD:
      vault:
        engine:
          name: kv-v2
          path: secret
        field: password
        path: cicd/database
  script:
    - echo "DB password available as $DATABASE_PASSWORD"
```

### 7. Bật AppRole Auth (cho ứng dụng tự động)

```bash
# Bật AppRole auth method
vault auth enable approle

# Tạo role cho ứng dụng
vault write auth/approle/role/my-app \
    token_policies="cicd-readonly" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=720h

# Lấy Role ID (public, có thể lưu trong config)
vault read auth/approle/role/my-app/role-id

# Sinh Secret ID (bí mật, truyền cho app qua secure channel)
vault write -f auth/approle/role/my-app/secret-id
```

Ứng dụng sẽ authenticate bằng `role_id` + `secret_id` để nhận token.

### 8. Dynamic Secrets - PostgreSQL (nâng cao)

```bash
# Bật database secret engine
vault secrets enable database

# Cấu hình PostgreSQL connection
vault write database/config/gitlab-postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="readonly" \
    connection_url="postgresql://{{username}}:{{password}}@172.23.1.16:5432/gitlabhq_production?sslmode=disable" \
    username="vault_admin" \
    password="vault_admin_password"

# Tạo role sinh dynamic credentials (tự động tạo user PostgreSQL tạm thời)
vault write database/roles/readonly \
    db_name=gitlab-postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Sinh credentials tạm thời (tự hủy sau 1h)
vault read database/creds/readonly
```

---

## Vận hành Production

### Backup & Restore

```bash
# Tạo snapshot (backup Raft data)
make snapshot
# Output: vault-snapshot-20260714-091500.snap

# Restore từ snapshot
make restore
# Nhập đường dẫn file: ./vault-snapshot-20260714-091500.snap
```

> 💡 Nên tạo cron job backup hàng ngày:
> ```bash
> # crontab -e
> 0 2 * * * cd /path/to/vault && make snapshot
> ```

### Renew Certificate

Let's Encrypt cert có hiệu lực 90 ngày. Tự động renew:

```bash
# Renew thủ công
make ssl-renew

# Tự động bằng cron (mỗi 60 ngày)
# crontab -e
0 3 1 */2 * cd /path/to/vault && make ssl-renew
```

### Audit Log (bật ghi log mọi hoạt động)

```bash
# Bật audit log (ghi ra file)
vault audit enable file file_path=/vault/logs/audit.log

# Bật audit log (ghi ra syslog)
vault audit enable syslog
```

### Monitoring

Vault expose metrics tại endpoint Prometheus:

```
https://vault.cloudsb.space:8200/v1/sys/metrics?format=prometheus
```

Cấu hình Prometheus scrape:
```yaml
scrape_configs:
  - job_name: 'vault'
    scheme: https
    tls_config:
      insecure_skip_verify: true  # nếu dùng self-signed
    metrics_path: /v1/sys/metrics
    params:
      format: ['prometheus']
    static_configs:
      - targets: ['vault.cloudsb.space:8200']
```

---

## Production Checklist

- [ ] Domain DNS trỏ đúng về server
- [ ] Let's Encrypt cert đã cấp thành công
- [ ] Vault đã init và unseal keys đã backup an toàn
- [ ] Root token đã lưu an toàn, tạo admin token riêng để dùng hàng ngày
- [ ] Đã tạo policies phân quyền (không dùng root token cho ứng dụng)
- [ ] Đã bật audit log
- [ ] Đã thiết lập cron renew cert (mỗi 60 ngày)
- [ ] Đã thiết lập cron backup snapshot (hàng ngày)
- [ ] Đã test restore từ snapshot
- [ ] Firewall chỉ mở port 8200 (API) và 8201 (cluster) cho các IP cần thiết

## Troubleshooting

### Vault sealed sau khi restart
Vault luôn sealed khi container restart. Cần unseal lại:
```bash
make unseal   # chạy 3 lần với 3 key khác nhau
```

> 💡 Trong production thật, nên dùng [Auto-Unseal](https://developer.hashicorp.com/vault/docs/configuration/seal) với AWS KMS, GCP Cloud KMS, hoặc Azure Key Vault để tự động unseal.

### Kiểm tra logs khi có lỗi
```bash
make logs
# hoặc xem audit log
docker exec vault cat /vault/logs/vault.log
```

### Quên root token
Nếu có đủ unseal keys (3/5), có thể tạo root token mới:
```bash
docker compose exec vault vault operator generate-root -init -tls-skip-verify
# Sau đó cung cấp 3 unseal keys để sinh root token mới
```

### Mất hết unseal keys
**Không thể khôi phục.** Đây là thiết kế bảo mật của Vault. Cần deploy Vault mới và restore từ snapshot (nếu có backup).
