#!/bin/bash
# ================================================================
# Sinh SSL Self-Signed Certificate cho GitLab
# Chạy trên máy GitLab Server trước khi docker compose up
# ================================================================

set -euo pipefail

load_env_file() {
    local file="$1"
    if [ -f "${file}" ]; then
        while IFS='=' read -r key value || [ -n "$key" ]; do
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'"'"']//' -e 's/["'"'"']$//')
            if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                export "$key"="$value"
            fi
        done < "${file}"
    fi
}

load_env_file .env.default
load_env_file .env

GITLAB_HOST="${GITLAB_HOST:-172.23.1.16}"
CERT_DIR="./ssl"
CERT_DAYS=3650  # 10 năm

echo "================================================"
echo "  Sinh SSL Self-Signed Certificate"
echo "  Host: ${GITLAB_HOST}"
echo "  Thư mục: ${CERT_DIR}"
echo "  Hiệu lực: ${CERT_DAYS} ngày"
echo "================================================"

# Tạo thư mục
mkdir -p "${CERT_DIR}"

# Kiểm tra xem GITLAB_HOST là IP hay Domain để cấu hình subjectAltName (SAN) cho đúng
if [[ "$GITLAB_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SAN="IP:${GITLAB_HOST},DNS:localhost,IP:127.0.0.1"
else
    SAN="DNS:${GITLAB_HOST},DNS:localhost,IP:127.0.0.1"
fi

# Sinh private key + certificate
openssl req -x509 -nodes \
    -days ${CERT_DAYS} \
    -newkey rsa:4096 \
    -keyout "${CERT_DIR}/${GITLAB_HOST}.key" \
    -out "${CERT_DIR}/${GITLAB_HOST}.crt" \
    -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=Self-Hosted/OU=GitLab/CN=${GITLAB_HOST}" \
    -addext "subjectAltName=${SAN}"

# Đặt quyền
chmod 600 "${CERT_DIR}/${GITLAB_HOST}.key"
chmod 644 "${CERT_DIR}/${GITLAB_HOST}.crt"

echo ""
echo "✅ Certificate đã sinh thành công:"
echo "   Key:  ${CERT_DIR}/${GITLAB_HOST}.key"
echo "   Cert: ${CERT_DIR}/${GITLAB_HOST}.crt"
echo ""
echo "📋 Thông tin cert:"
openssl x509 -in "${CERT_DIR}/${GITLAB_HOST}.crt" -noout -subject -dates -ext subjectAltName
echo ""
echo "📦 Copy cert sang máy Runner để trust:"
echo "   scp ${CERT_DIR}/${GITLAB_HOST}.crt user@<runner-host>:~/gitlab-runner/ssl/"
