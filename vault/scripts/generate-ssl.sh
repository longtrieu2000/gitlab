#!/bin/bash
# ================================================================
# Sinh SSL Self-Signed Certificate cho Vault
# Chạy trên máy Vault Server trước khi docker compose up
# ================================================================

set -euo pipefail

# Chuyển về thư mục chứa script để đảm bảo chạy đúng đường dẫn tương đối
cd "$(dirname "$0")/.."

# Load biến từ .env
if [ -f .env ]; then
    source .env
elif [ -f .env.default ]; then
    source .env.default
else
    echo "❌ Không tìm thấy .env hoặc .env.default"
    exit 1
fi

VAULT_HOST="${VAULT_HOST:-vault.cloudsb.space}"
CERT_DIR="./ssl"
CERT_DAYS=3650  # 10 năm

echo "================================================"
echo "  Sinh SSL Self-Signed Certificate cho Vault"
echo "  Host: ${VAULT_HOST}"
echo "  Thư mục: ${CERT_DIR}"
echo "  Hiệu lực: ${CERT_DAYS} ngày"
echo "================================================"

# Tạo thư mục
mkdir -p "${CERT_DIR}"

# Kiểm tra xem VAULT_HOST là IP hay Domain để cấu hình SAN
if [[ "$VAULT_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SAN="IP:${VAULT_HOST},DNS:localhost,IP:127.0.0.1"
else
    SAN="DNS:${VAULT_HOST},DNS:localhost,IP:127.0.0.1"
fi

# Sinh private key + certificate (dùng tên fullchain.pem/privkey.pem để thống nhất với Let's Encrypt)
openssl req -x509 -nodes \
    -days ${CERT_DAYS} \
    -newkey rsa:4096 \
    -keyout "${CERT_DIR}/privkey.pem" \
    -out "${CERT_DIR}/fullchain.pem" \
    -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=Self-Hosted/OU=Vault/CN=${VAULT_HOST}" \
    -addext "subjectAltName=${SAN}"

# Đặt quyền
chmod 600 "${CERT_DIR}/privkey.pem"
chmod 644 "${CERT_DIR}/fullchain.pem"

echo ""
echo "✅ Certificate đã sinh thành công:"
echo "   Cert: ${CERT_DIR}/fullchain.pem"
echo "   Key:  ${CERT_DIR}/privkey.pem"
echo ""
echo "📋 Thông tin cert:"
openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -subject -dates -ext subjectAltName
echo ""
echo "⚠️  Lưu ý: Self-signed cert cần trust thủ công trên client."
echo "   Vault CLI: export VAULT_SKIP_VERIFY=true"
