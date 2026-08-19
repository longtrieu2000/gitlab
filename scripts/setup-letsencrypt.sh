#!/bin/bash
# ================================================================
# Import Let's Encrypt Certificate cho GitLab
# Chạy trên máy GitLab Server sau khi lấy cert bằng Certbot DNS challenge
# ================================================================

set -euo pipefail

# Chuyển về thư mục chứa script để đảm bảo chạy đúng đường dẫn tương đối
cd "$(dirname "$0")/.."

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

GITLAB_HOST="${GITLAB_HOST:-gitlab.cloud.sb}"
CERT_DIR="./ssl"
LE_DIR="/etc/letsencrypt/live/${GITLAB_HOST}"

echo "================================================="
echo "⚙️  Đang thiết lập SSL Let's Encrypt cho GitLab"
echo "🌐 Domain: ${GITLAB_HOST}"
echo "📂 Thư mục đích: ${CERT_DIR}"
echo "================================================="

# Kiểm tra thư mục Let's Encrypt
if [ ! -d "${LE_DIR}" ]; then
    echo "❌ Không tìm thấy thư mục chứng chỉ Let's Encrypt tại:"
    echo "   ${LE_DIR}"
    echo ""
    echo "👉 Vui lòng chạy lệnh Certbot để lấy chứng chỉ trước:"
    echo "   sudo apt update && sudo apt install -y certbot"
    echo "   sudo certbot certonly --manual --preferred-challenges dns -d ${GITLAB_HOST}"
    echo ""
    echo "⚠️  Lưu ý: Bạn cần cấu hình bản ghi TXT '_acme-challenge.${GITLAB_HOST}' tại DNS server."
    exit 1
fi

# Tạo thư mục ssl
mkdir -p "${CERT_DIR}"

echo "📂 Đang sao chép chứng chỉ Let's Encrypt..."

# Thực hiện sao chép (Sử dụng sudo nếu cần thiết vì /etc/letsencrypt thường yêu cầu quyền root)
if [ -r "${LE_DIR}/fullchain.pem" ] && [ -r "${LE_DIR}/privkey.pem" ]; then
    cp "${LE_DIR}/fullchain.pem" "${CERT_DIR}/${GITLAB_HOST}.crt"
    cp "${LE_DIR}/privkey.pem" "${CERT_DIR}/${GITLAB_HOST}.key"
else
    echo "🔑 Cần quyền sudo để đọc thư mục /etc/letsencrypt. Đang thử bằng sudo..."
    sudo cp "${LE_DIR}/fullchain.pem" "${CERT_DIR}/${GITLAB_HOST}.crt"
    sudo cp "${LE_DIR}/privkey.pem" "${CERT_DIR}/${GITLAB_HOST}.key"
fi

# Đặt lại quyền sở hữu về user hiện tại để dễ quản lý
USER_UID=$(id -u)
USER_GID=$(id -g)
sudo chown "${USER_UID}:${USER_GID}" "${CERT_DIR}/${GITLAB_HOST}.crt" "${CERT_DIR}/${GITLAB_HOST}.key" 2>/dev/null || true

# Phân quyền chuẩn cho SSL Cert & Key
chmod 644 "${CERT_DIR}/${GITLAB_HOST}.crt"
chmod 600 "${CERT_DIR}/${GITLAB_HOST}.key"

echo ""
echo "✅ Đã import chứng chỉ Let's Encrypt thành công!"
echo "   📜 Cert file: ${CERT_DIR}/${GITLAB_HOST}.crt (Full Chain)"
echo "   🔑 Key file:  ${CERT_DIR}/${GITLAB_HOST}.key"
echo ""
echo "📝 Tiếp theo: Đảm bảo thiết lập trong .env là SSL_TYPE=letsencrypt"
echo "🚀 Chạy 'make up' để áp dụng cấu hình và restart GitLab!"
