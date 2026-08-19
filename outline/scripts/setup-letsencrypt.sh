#!/bin/bash
# ================================================================
# Import Let's Encrypt Certificate cho Outline Wiki
# Domain: outline.cloudsb.space
# Chạy trên máy chủ sau khi lấy cert bằng Certbot DNS challenge
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
LE_DIR="/etc/letsencrypt/live/${OUTLINE_HOST}"

echo "================================================="
echo "⚙️  Đang thiết lập SSL Let's Encrypt cho Outline"
echo "🌐 Domain: ${OUTLINE_HOST}"
echo "📂 Thư mục đích: ${CERT_DIR}"
echo "================================================="

# Kiểm tra thư mục Let's Encrypt
if [ ! -d "${LE_DIR}" ]; then
    echo "❌ Không tìm thấy thư mục chứng chỉ Let's Encrypt tại:"
    echo "   ${LE_DIR}"
    echo ""
    echo "👉 Vui lòng chạy lệnh Certbot để lấy chứng chỉ trước:"
    echo "   sudo apt update && sudo apt install -y certbot"
    echo "   sudo certbot certonly --manual --preferred-challenges dns -d ${OUTLINE_HOST}"
    echo ""
    echo "⚠️  Lưu ý: Bạn cần cấu hình bản ghi TXT '_acme-challenge.${OUTLINE_HOST}' tại DNS server của cloudsb.space."
    exit 1
fi

# Tạo thư mục ssl
mkdir -p "${CERT_DIR}"

echo "📂 Đang sao chép chứng chỉ Let's Encrypt..."

# Sao chép cert (fullchain + privkey)
if [ -r "${LE_DIR}/fullchain.pem" ] && [ -r "${LE_DIR}/privkey.pem" ]; then
    cp -f "${LE_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
    cp -f "${LE_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem"
else
    echo "🔑 Cần quyền sudo để đọc thư mục /etc/letsencrypt. Đang thử bằng sudo..."
    sudo cp -f "${LE_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
    sudo cp -f "${LE_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem"
fi

# Đồng thời tạo bản sao theo tên domain
cp -f "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt"
cp -f "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.key"

# Đặt lại quyền sở hữu về user hiện tại để dễ quản lý
USER_UID=$(id -u)
USER_GID=$(id -g)
sudo chown "${USER_UID}:${USER_GID}" "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt" "${CERT_DIR}/${OUTLINE_HOST}.key" 2>/dev/null || true

# Phân quyền chuẩn cho SSL Cert & Key
chmod 644 "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt"
chmod 600 "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.key"

echo ""
echo "✅ Đã import chứng chỉ Let's Encrypt thành công!"
echo "   📜 Cert file: ${CERT_DIR}/fullchain.pem (Full Chain)"
echo "   🔑 Key file:  ${CERT_DIR}/privkey.pem"
echo ""
echo "📋 Thông tin cert:"
openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -subject -dates -ext subjectAltName
echo ""
echo "🚀 Tiếp theo: Chạy 'docker compose up -d' hoặc 'make up' để khởi động Outline!"
