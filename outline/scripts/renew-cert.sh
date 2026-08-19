#!/bin/bash
# ================================================================
# Renew Let's Encrypt Certificate và reload Nginx cho Outline Wiki
# Domain: outline.cloudsb.space
# ================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

# Load biến
if [ -f .env ]; then
    source .env
elif [ -f .env.default ]; then
    source .env.default
fi

OUTLINE_HOST="${OUTLINE_HOST:-outline.cloudsb.space}"
CERT_DIR="./ssl"
LE_DIR="/etc/letsencrypt/live/${OUTLINE_HOST}"

echo "🔄 Đang renew certificate Let's Encrypt cho ${OUTLINE_HOST}..."
sudo certbot renew --cert-name "${OUTLINE_HOST}" --quiet

echo "📂 Đang cập nhật certificate vào ${CERT_DIR}..."
sudo cp -f "${LE_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
sudo cp -f "${LE_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem"
cp -f "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt" 2>/dev/null || sudo cp -f "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt"
cp -f "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.key" 2>/dev/null || sudo cp -f "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.key"

USER_UID=$(id -u)
USER_GID=$(id -g)
sudo chown "${USER_UID}:${USER_GID}" "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt" "${CERT_DIR}/${OUTLINE_HOST}.key" 2>/dev/null || true
chmod 644 "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/${OUTLINE_HOST}.crt"
chmod 600 "${CERT_DIR}/privkey.pem" "${CERT_DIR}/${OUTLINE_HOST}.key"

echo "🔄 Đang reload Nginx để áp dụng cert mới..."
docker compose exec nginx nginx -s reload

echo ""
echo "✅ Certificate đã renew và Nginx đã reload thành công!"
openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -dates
