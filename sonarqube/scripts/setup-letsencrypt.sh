#!/bin/bash
# ================================================================
# Import Let's Encrypt Certificate cho SonarQube
# Chạy trên máy chủ sau khi lấy cert bằng Certbot DNS challenge
# ================================================================

set -euo pipefail

# Chuyển về thư mục chứa script để đảm bảo chạy đúng đường dẫn tương đối
cd "$(dirname "$0")/.."

# Load biến từ .env hoặc .env.default
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
LE_DIR="/etc/letsencrypt/live/${SONARQUBE_HOST}"

echo "================================================="
echo "⚙️  Đang thiết lập SSL Let's Encrypt cho SonarQube"
echo "🌐 Domain: ${SONARQUBE_HOST}"
echo "📂 Thư mục đích: ${CERT_DIR}"
echo "================================================="

# Kiểm tra thư mục Let's Encrypt
if [ ! -d "${LE_DIR}" ]; then
    echo "❌ Không tìm thấy thư mục chứng chỉ Let's Encrypt tại:"
    echo "   ${LE_DIR}"
    echo ""
    echo "👉 Vui lòng chạy lệnh Certbot để lấy chứng chỉ trước:"
    echo "   sudo apt update && sudo apt install -y certbot"
    echo "   sudo certbot certonly --manual --preferred-challenges dns -d ${SONARQUBE_HOST}"
    echo ""
    echo "⚠️  Lưu ý: Bạn cần cấu hình bản ghi TXT '_acme-challenge.${SONARQUBE_HOST}' tại DNS server."
    exit 1
fi

# Tạo thư mục ssl
mkdir -p "${CERT_DIR}"

echo "📂 Đang sao chép chứng chỉ Let's Encrypt..."

# Sao chép cert (fullchain + privkey)
if [ -r "${LE_DIR}/fullchain.pem" ] && [ -r "${LE_DIR}/privkey.pem" ]; then
    cp "${LE_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
    cp "${LE_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem"
else
    echo "🔑 Cần quyền sudo để đọc thư mục /etc/letsencrypt. Đang thử bằng sudo..."
    sudo cp "${LE_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
    sudo cp "${LE_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem"
fi

# Đặt lại quyền sở hữu về user hiện tại để dễ quản lý
USER_UID=$(id -u)
USER_GID=$(id -g)
sudo chown "${USER_UID}:${USER_GID}" "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" 2>/dev/null || true

# Phân quyền chuẩn cho SSL Cert & Key
chmod 644 "${CERT_DIR}/fullchain.pem"
chmod 600 "${CERT_DIR}/privkey.pem"

echo ""
echo "✅ Đã import chứng chỉ Let's Encrypt thành công!"
echo "   📜 Cert file: ${CERT_DIR}/fullchain.pem (Full Chain)"
echo "   🔑 Key file:  ${CERT_DIR}/privkey.pem"
echo ""
echo "📋 Thông tin cert:"
openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -subject -dates -ext subjectAltName
echo ""
echo "📝 Tiếp theo: Chạy 'make up' để khởi động SonarQube!"
