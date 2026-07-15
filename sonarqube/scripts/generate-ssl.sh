#!/bin/bash
# ================================================================
# Sinh SSL Self-Signed Certificate cho SonarQube
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

SONARQUBE_HOST="${SONARQUBE_HOST:-sonarqube.cloudsb.space}"
CERT_DIR="./ssl"
CERT_DAYS=3650  # 10 năm

echo "================================================"
echo "  Sinh SSL Self-Signed Certificate cho SonarQube"
echo "  Host: ${SONARQUBE_HOST}"
echo "  Thư mục: ${CERT_DIR}"
echo "  Hiệu lực: ${CERT_DAYS} ngày"
echo "================================================"

# Tạo thư mục ssl
mkdir -p "${CERT_DIR}"

# Kiểm tra xem SONARQUBE_HOST là IP hay Domain để cấu hình SAN
if [[ "$SONARQUBE_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SAN="IP:${SONARQUBE_HOST},DNS:localhost,IP:127.0.0.1"
else
    SAN="DNS:${SONARQUBE_HOST},DNS:localhost,IP:127.0.0.1"
fi

# Sinh private key + certificate (dùng tên fullchain.pem/privkey.pem để thống nhất với Let's Encrypt)
openssl req -x509 -nodes \
    -days ${CERT_DAYS} \
    -newkey rsa:4096 \
    -keyout "${CERT_DIR}/privkey.pem" \
    -out "${CERT_DIR}/fullchain.pem" \
    -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=Self-Hosted/OU=SonarQube/CN=${SONARQUBE_HOST}" \
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
