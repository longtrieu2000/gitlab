#!/bin/bash
# ================================================================
# Sinh SSL Self-Signed Certificate cho Outline Wiki
# Domain: outline.cloudsb.space (hoặc cấu hình qua biến OUTLINE_HOST)
# ================================================================

set -euo pipefail

# Chuyển về thư mục chứa service outline để đảm bảo đường dẫn tương đối chính xác
cd "$(dirname "$0")/.."

# Load biến từ .env hoặc .env.default nếu có
if [ -f .env ]; then
    source .env
elif [ -f .env.default ]; then
    source .env.default
fi

OUTLINE_HOST="${OUTLINE_HOST:-outline.cloudsb.space}"
CERT_DIR="./ssl"
CERT_DAYS=3650  # 10 năm

echo "================================================"
echo "  Sinh SSL Self-Signed Certificate cho Outline"
echo "  Host: ${OUTLINE_HOST}"
echo "  Thư mục đích: ${CERT_DIR}"
echo "  Thời hạn: ${CERT_DAYS} ngày"
echo "================================================"

# Tạo thư mục ssl
mkdir -p "${CERT_DIR}"

# Kiểm tra xem OUTLINE_HOST là IP hay Domain để cấu hình SAN (Subject Alternative Name)
if [[ "$OUTLINE_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SAN="IP:${OUTLINE_HOST},DNS:localhost,IP:127.0.0.1"
else
    SAN="DNS:${OUTLINE_HOST},DNS:localhost,IP:127.0.0.1"
fi

# Sinh private key + certificate (RSA 4096-bit, SHA-256)
openssl req -x509 -nodes \
    -days ${CERT_DAYS} \
    -newkey rsa:4096 \
    -keyout "${CERT_DIR}/privkey.pem" \
    -out "${CERT_DIR}/fullchain.pem" \
    -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=Self-Hosted/OU=Outline/CN=${OUTLINE_HOST}" \
    -addext "subjectAltName=${SAN}"

# Đồng thời tạo bản sao/link theo định dạng domain để tương thích đa dạng cấu hình
cp -f "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt"
cp -f "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.key"

# Thiết lập quyền bảo mật chuẩn
chmod 600 "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.key"
chmod 644 "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt"

echo ""
echo "✅ SSL Certificate đã được tạo thành công:"
echo "   📜 Cert file: ${CERT_DIR}/fullchain.pem (và ${CERT_DIR}/${OUTLINE_HOST}.crt)"
echo "   🔑 Key file:  ${CERT_DIR}/privkey.pem (và ${CERT_DIR}/${OUTLINE_HOST}.key)"
echo ""
echo "📋 Thông tin chứng chỉ vừa sinh:"
openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -subject -dates -ext subjectAltName
echo ""
echo "🚀 Tiếp theo: Chạy 'docker compose up -d' hoặc 'make up' để khởi chạy Outline!"
