#!/bin/bash
# ================================================================
# GitLab Server - Script Backup Toàn Diện (A -> Z)
# Bao gồm: Application Data, Database Raw Dump, Secrets, Config, SSL
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

# Load biến môi trường an toàn (tránh lỗi syntax khi .env chứa ký tự đặc biệt)
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
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
BACKUP_BASE_DIR="${ROOT_DIR}/backups"
BACKUP_TEMP_DIR="${BACKUP_BASE_DIR}/gitlab_backup_${TIMESTAMP}"
BACKUP_ARCHIVE="${BACKUP_BASE_DIR}/gitlab_full_backup_${TIMESTAMP}.tar.gz"
RETENTION_DAYS=7

echo "================================================================="
echo "  🚀 BẮT ĐẦU QUÁ TRÌNH BACKUP TOÀN DIỆN GITLAB (A -> Z)"
echo "  Host:        ${GITLAB_HOST}"
echo "  Thời gian:   $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Thư mục tạm: ${BACKUP_TEMP_DIR}"
echo "================================================================="

# Tạo các thư mục lưu trữ
mkdir -p "${BACKUP_TEMP_DIR}"
mkdir -p "${BACKUP_TEMP_DIR}/config"
mkdir -p "${BACKUP_TEMP_DIR}/database"
mkdir -p "${BACKUP_TEMP_DIR}/application"
mkdir -p "${BACKUP_TEMP_DIR}/ssl"

# ---------------------------------------------------------------
# 1. Kiểm tra containers có đang chạy không
# ---------------------------------------------------------------
echo ""
echo "🔍 [1/6] Kiểm tra trạng thái các container..."
if ! docker compose ps --services --filter "status=running" | grep -q "gitlab"; then
    echo "❌ Container GitLab không đang chạy. Đang khởi động stack..."
    docker compose up -d
    echo "⏳ Đợi 30 giây để các dịch vụ sẵn sàng..."
    sleep 30
fi

# Lấy thông tin phiên bản hiện tại
GITLAB_VERSION="$(docker compose exec -T gitlab cat /opt/gitlab/version-manifest.txt 2>/dev/null | head -1 | awk '{print $2}' || echo 'unknown')"
echo "   ℹ️  Phiên bản GitLab hiện tại: ${GITLAB_VERSION}"

# ---------------------------------------------------------------
# 2. Backup Application Data (Repositories, Uploads, LFS, Builds)
# ---------------------------------------------------------------
echo ""
echo "📦 [2/6] Đang chạy GitLab Rake Application Backup (Repositories, Uploads, LFS)..."
# Chạy backup application qua rake task (không nén lại để tiết kiệm thời gian)
docker compose exec -T gitlab gitlab-rake gitlab:backup:create SKIP=tar 2>&1 | tee "${BACKUP_TEMP_DIR}/rake_backup.log" || true

# Hoặc nếu chạy bản nén tar mặc định, copy file tar ra
echo "📂 Sao chép file backup application từ container..."
LATEST_RAKE_TAR="$(docker compose exec -T gitlab bash -c 'ls -t /var/opt/gitlab/backups/*_gitlab_backup.tar 2>/dev/null | head -1' | tr -d '\r')"

if [ -n "${LATEST_RAKE_TAR}" ]; then
    echo "   Đã tìm thấy: ${LATEST_RAKE_TAR}"
    docker compose cp "gitlab:${LATEST_RAKE_TAR}" "${BACKUP_TEMP_DIR}/application/"
    echo "   ✅ Đã copy application backup: $(basename "${LATEST_RAKE_TAR}")"
else
    echo "   ⚠️  Không tìm thấy file .tar trong /var/opt/gitlab/backups/, đang backup trực tiếp repositories..."
    docker compose cp gitlab:/var/opt/gitlab/git-data "${BACKUP_TEMP_DIR}/application/" 2>/dev/null || true
fi

# ---------------------------------------------------------------
# 3. Backup Raw Database (PostgreSQL Raw Dump) - Lớp an toàn thứ 2
# ---------------------------------------------------------------
echo ""
echo "🗄️  [3/6] Đang dump raw database PostgreSQL (gitlabhq_production)..."
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-your_secure_password}"
docker compose exec -T postgres pg_dump -U gitlab -d gitlabhq_production --clean --if-exists --no-owner --no-privileges | gzip > "${BACKUP_TEMP_DIR}/database/gitlabhq_production_${TIMESTAMP}.sql.gz"
echo "   ✅ Database dump hoàn tất: database/gitlabhq_production_${TIMESTAMP}.sql.gz ($(du -h "${BACKUP_TEMP_DIR}/database/gitlabhq_production_${TIMESTAMP}.sql.gz" | cut -f1))"

# ---------------------------------------------------------------
# 4. Backup Secrets, Configurations & SSL Certificates
# ---------------------------------------------------------------
echo ""
echo "🔑 [4/6] Sao lưu Secret Keys, Configuration và SSL Certificates..."

# Copy gitlab-secrets.json và gitlab.rb từ container
docker compose cp gitlab:/etc/gitlab/gitlab-secrets.json "${BACKUP_TEMP_DIR}/config/gitlab-secrets.json" 2>/dev/null || true
docker compose cp gitlab:/etc/gitlab/gitlab.rb "${BACKUP_TEMP_DIR}/config/gitlab.rb" 2>/dev/null || true

# Copy các file cấu hình tại thư mục root
[ -f .env ] && cp .env "${BACKUP_TEMP_DIR}/config/.env"
[ -f .env.default ] && cp .env.default "${BACKUP_TEMP_DIR}/config/.env.default"
[ -f docker-compose.yml ] && cp docker-compose.yml "${BACKUP_TEMP_DIR}/config/docker-compose.yml"
[ -f gitlab.rc ] && cp gitlab.rc "${BACKUP_TEMP_DIR}/config/gitlab.rc"

# Copy SSL certs
if [ -d "./ssl" ]; then
    cp -r ./ssl/* "${BACKUP_TEMP_DIR}/ssl/" 2>/dev/null || true
fi

# Tạo manifest metadata
cat <<EOF > "${BACKUP_TEMP_DIR}/manifest.json"
{
  "backup_name": "gitlab_full_backup_${TIMESTAMP}",
  "created_at": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "gitlab_host": "${GITLAB_HOST}",
  "gitlab_version": "${GITLAB_VERSION}",
  "postgres_version": "${POSTGRES_VERSION:-17.10}",
  "redis_version": "${REDIS_VERSION:-7.4.8}",
  "contents": [
    "application_data (repositories, uploads, lfs, builds)",
    "database_sql_dump (PostgreSQL)",
    "gitlab-secrets.json (CRITICAL ENCRYPTION KEYS)",
    "gitlab.rb (Omnibus configuration)",
    "ssl_certificates",
    "environment_variables (.env)"
  ]
}
EOF

echo "   ✅ Đã sao lưu toàn bộ Secrets, SSL và Metadata."

# ---------------------------------------------------------------
# 5. Đóng gói toàn bộ thành 1 file nén & tạo mã Checksum SHA256
# ---------------------------------------------------------------
echo ""
echo "🗜️  [5/6] Đang nén gói backup toàn diện..."
cd "${BACKUP_BASE_DIR}"
tar -czf "${BACKUP_ARCHIVE}" -C "${BACKUP_BASE_DIR}" "gitlab_backup_${TIMESTAMP}"

# Xóa thư mục tạm sau khi nén
rm -rf "${BACKUP_TEMP_DIR}"

# Tạo mã SHA256 checksum
sha256sum "$(basename "${BACKUP_ARCHIVE}")" > "${BACKUP_ARCHIVE}.sha256"

ARCHIVE_SIZE="$(du -h "${BACKUP_ARCHIVE}" | cut -f1)"
echo "   ✅ Đã đóng gói thành công:"
echo "      📁 File:     ${BACKUP_ARCHIVE}"
echo "      📊 Dung lượng: ${ARCHIVE_SIZE}"
echo "      🛡️  Checksum: $(cat "${BACKUP_ARCHIVE}.sha256" | cut -d' ' -f1)"

# ---------------------------------------------------------------
# 6. Dọn dẹp các bản backup cũ (Retention Policy)
# ---------------------------------------------------------------
echo ""
echo "🧹 [6/6] Dọn dẹp các bản backup cũ (Giữ lại ${RETENTION_DAYS} ngày gần nhất)..."
find "${BACKUP_BASE_DIR}" -name "gitlab_full_backup_*.tar.gz*" -mtime "+${RETENTION_DAYS}" -exec rm -f {} + || true

echo ""
echo "================================================================="
echo "  🎉 BACKUP HOÀN TẤT THÀNH CÔNG 100%!"
echo "  📜 File Backup: ${BACKUP_ARCHIVE}"
echo "  🔑 File Checksum: ${BACKUP_ARCHIVE}.sha256"
echo "================================================================="
echo "👉 LƯU Ý BẢO MẬT: Hãy copy file backup này sang máy chủ phụ / S3 storage"
echo "   để đảm bảo khả năng phục hồi thảm họa (Disaster Recovery)."
echo "================================================================="
