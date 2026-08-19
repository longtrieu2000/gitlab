#!/bin/bash
# ================================================================
# GitLab Server - Script Khôi Phục Toàn Diện (Restore A -> Z)
# Phục hồi từ file nén gitlab_full_backup_*.tar.gz
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

BACKUP_BASE_DIR="${ROOT_DIR}/backups"
ARCHIVE_INPUT="${1:-}"

echo "================================================================="
echo "  ♻️  BẮT ĐẦU QUÁ TRÌNH KHÔI PHỤC TOÀN DIỆN GITLAB (RESTORE A -> Z)"
echo "  Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================="

# 1. Tìm hoặc kiểm tra file backup
if [ -z "${ARCHIVE_INPUT}" ]; then
    echo "🔍 Không có file nào được chỉ định. Đang tìm bản backup gần nhất..."
    ARCHIVE_INPUT="$(ls -t "${BACKUP_BASE_DIR}"/gitlab_full_backup_*.tar.gz 2>/dev/null | head -1 || true)"
    if [ -z "${ARCHIVE_INPUT}" ]; then
        echo "❌ Không tìm thấy bản backup nào trong ${BACKUP_BASE_DIR}"
        echo "   Cách dùng: bash scripts/restore-all.sh <đường_dẫn_file_backup.tar.gz>"
        exit 1
    fi
fi

if [ ! -f "${ARCHIVE_INPUT}" ]; then
    echo "❌ File backup không tồn tại: ${ARCHIVE_INPUT}"
    exit 1
fi

echo "📁 File backup được chọn: ${ARCHIVE_INPUT}"
echo "📊 Dung lượng: $(du -h "${ARCHIVE_INPUT}" | cut -f1)"

# 2. Kiểm tra mã SHA256 Checksum (nếu có)
CHECKSUM_FILE="${ARCHIVE_INPUT}.sha256"
if [ -f "${CHECKSUM_FILE}" ]; then
    echo ""
    echo "🛡️  Đang kiểm tra tính toàn vẹn SHA256 Checksum..."
    cd "$(dirname "${ARCHIVE_INPUT}")"
    if sha256sum -c "$(basename "${CHECKSUM_FILE}")" --status; then
        echo "   ✅ Checksum hợp lệ 100%!"
    else
        echo "   ❌ CẢNH BÁO: Checksum không khớp! File backup có thể đã bị hỏng."
        read -rp "Bạn có chắc chắn muốn tiếp tục không? (y/N): " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    cd "${ROOT_DIR}"
fi

# 3. Cảnh báo và yêu cầu xác nhận
echo ""
echo "⚠️  CẢNH BÁO CỰC KỲ QUAN TRỌNG:"
echo "   Quá trình Restore sẽ GHI ĐÈ toàn bộ dữ liệu, database và cấu hình hiện tại của GitLab."
read -rp "👉 Bạn có chắc chắn muốn tiến hành khôi phục? (gõ 'YES' để xác nhận): " CONFIRM_RESTORE
if [ "${CONFIRM_RESTORE}" != "YES" ]; then
    echo "❌ Đã hủy thao tác khôi phục."
    exit 0
fi

# 4. Giải nén gói backup vào thư mục tạm
RESTORE_TEMP="${ROOT_DIR}/restore_temp_$(date +'%s')"
mkdir -p "${RESTORE_TEMP}"
echo ""
echo "🗜️  [1/5] Đang giải nén gói backup..."
tar -xzf "${ARCHIVE_INPUT}" -C "${RESTORE_TEMP}"

BACKUP_FOLDER="$(ls "${RESTORE_TEMP}" | head -1)"
EXTRACTED_DIR="${RESTORE_TEMP}/${BACKUP_FOLDER}"

if [ -f "${EXTRACTED_DIR}/manifest.json" ]; then
    echo "📋 Thông tin bản backup:"
    cat "${EXTRACTED_DIR}/manifest.json"
fi

# 5. Khôi phục Cấu hình, Secrets và SSL
echo ""
echo "🔑 [2/5] Đang khôi phục Secrets, Configurations và SSL Certificates..."

# Khôi phục file cấu hình root
[ -f "${EXTRACTED_DIR}/config/.env" ] && cp -f "${EXTRACTED_DIR}/config/.env" .env
[ -f "${EXTRACTED_DIR}/config/docker-compose.yml" ] && cp -f "${EXTRACTED_DIR}/config/docker-compose.yml" docker-compose.yml
[ -f "${EXTRACTED_DIR}/config/gitlab.rc" ] && cp -f "${EXTRACTED_DIR}/config/gitlab.rc" gitlab.rc

# Khôi phục SSL
if [ -d "${EXTRACTED_DIR}/ssl" ]; then
    mkdir -p ./ssl
    cp -rf "${EXTRACTED_DIR}/ssl/"* ./ssl/ 2>/dev/null || true
fi

# Đảm bảo containers khởi chạy
docker compose up -d postgres redis
echo "⏳ Đợi 15 giây để Database & Redis sẵn sàng..."
sleep 15
docker compose up -d gitlab
echo "⏳ Đợi 30 giây để GitLab khởi động..."
sleep 30

# Khôi phục gitlab-secrets.json và gitlab.rb vào container
if [ -f "${EXTRACTED_DIR}/config/gitlab-secrets.json" ]; then
    echo "   Restoring gitlab-secrets.json..."
    docker compose cp "${EXTRACTED_DIR}/config/gitlab-secrets.json" gitlab:/etc/gitlab/gitlab-secrets.json
fi
if [ -f "${EXTRACTED_DIR}/config/gitlab.rb" ]; then
    echo "   Restoring gitlab.rb..."
    docker compose cp "${EXTRACTED_DIR}/config/gitlab.rb" gitlab:/etc/gitlab/gitlab.rb
fi

# 6. Khôi phục Raw Database (PostgreSQL)
echo ""
echo "🗄️  [3/5] Đang khôi phục Database PostgreSQL..."
DB_DUMP_FILE="$(ls "${EXTRACTED_DIR}/database/"*.sql.gz 2>/dev/null | head -1 || true)"
if [ -n "${DB_DUMP_FILE}" ]; then
    echo "   Dừng các dịch vụ kết nối DB trong GitLab để khôi phục..."
    docker compose exec -T gitlab gitlab-ctl stop puma || true
    docker compose exec -T gitlab gitlab-ctl stop sidekiq || true
    
    echo "   Đang nạp database dump vào PostgreSQL..."
    gunzip -c "${DB_DUMP_FILE}" | docker compose exec -T postgres psql -U gitlab -d gitlabhq_production
    echo "   ✅ Khôi phục Database thành công!"
fi

# 7. Khôi phục Application Data (Repositories, Uploads, LFS)
echo ""
echo "📦 [4/5] Đang khôi phục Application Data (Repositories, Uploads)..."
APP_TAR_FILE="$(ls "${EXTRACTED_DIR}/application/"*_gitlab_backup.tar 2>/dev/null | head -1 || true)"

if [ -n "${APP_TAR_FILE}" ]; then
    TAR_NAME="$(basename "${APP_TAR_FILE}")"
    BACKUP_TIMESTAMP_NAME="${TAR_NAME%_gitlab_backup.tar}"
    
    echo "   Copy ${TAR_NAME} vào /var/opt/gitlab/backups/ trong container..."
    docker compose cp "${APP_TAR_FILE}" "gitlab:/var/opt/gitlab/backups/${TAR_NAME}"
    docker compose exec -T gitlab chown git:git "/var/opt/gitlab/backups/${TAR_NAME}"
    
    echo "   Chạy lệnh khôi phục Rake task..."
    docker compose exec -T gitlab gitlab-rake gitlab:backup:restore BACKUP="${BACKUP_TIMESTAMP_NAME}" force=yes
    echo "   ✅ Khôi phục Application Data thành công!"
fi

# 8. Reconfigure & Restart GitLab
echo ""
echo "🔄 [5/5] Đang Reconfigure & Khởi động lại toàn bộ dịch vụ..."
docker compose exec -T gitlab gitlab-ctl reconfigure
docker compose exec -T gitlab gitlab-ctl restart

# Dọn dẹp thư mục tạm
rm -rf "${RESTORE_TEMP}"

echo ""
echo "================================================================="
echo "  🎉 KHÔI PHỤC DỮ LIỆU HOÀN TẤT THÀNH CÔNG 100%!"
echo "================================================================="
echo "👉 Hãy kiểm tra giao diện Web và chạy kiểm tra tính toàn vẹn:"
echo "   make ps"
echo "   docker compose exec gitlab gitlab-rake gitlab:check SANITIZE=true"
echo "================================================================="
