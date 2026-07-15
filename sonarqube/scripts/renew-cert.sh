#!/bin/bash
# ================================================================
# Renew Let's Encrypt Certificate và reload Nginx
# Chạy bằng cron hoặc systemd timer mỗi 60 ngày
# ================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

# Load biến
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

echo "🔄 Đang renew certificate Let's Encrypt..."
sudo certbot renew --cert-name "${SONARQUBE_HOST}" --quiet

echo "📂 Đang cập nhật certificate..."
sudo cp "${LE_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
sudo cp "${LE_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem"

USER_UID=$(id -u)
USER_GID=$(id -g)
sudo chown "${USER_UID}:${USER_GID}" "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem"
chmod 644 "${CERT_DIR}/fullchain.pem"
chmod 600 "${CERT_DIR}/privkey.pem"

echo "🔄 Đang reload Nginx để áp dụng cert mới..."
docker compose exec nginx nginx -s reload

echo ""
echo "✅ Certificate đã renew và Nginx đã reload!"
openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -dates
