#!/bin/bash
# ================================================================
# Renew Let's Encrypt Certificate và reload Vault
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

VAULT_HOST="${VAULT_HOST:-vault.cloudsb.space}"
CERT_DIR="./ssl"
LE_DIR="/etc/letsencrypt/live/${VAULT_HOST}"

echo "🔄 Đang renew certificate Let's Encrypt..."
sudo certbot renew --cert-name "${VAULT_HOST}" --quiet

echo "📂 Đang cập nhật certificate..."
sudo cp "${LE_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
sudo cp "${LE_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem"

USER_UID=$(id -u)
USER_GID=$(id -g)
sudo chown "${USER_UID}:${USER_GID}" "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem"
chmod 644 "${CERT_DIR}/fullchain.pem"
chmod 600 "${CERT_DIR}/privkey.pem"

echo "🔄 Đang reload Vault để áp dụng cert mới..."
docker compose exec vault vault operator reload-tls -tls-skip-verify 2>/dev/null || \
    docker compose restart vault

echo ""
echo "✅ Certificate đã renew và Vault đã reload!"
openssl x509 -in "${CERT_DIR}/fullchain.pem" -noout -dates
