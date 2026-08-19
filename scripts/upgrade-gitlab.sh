#!/bin/bash
# ================================================================
# GitLab Server - Script Hướng Dẫn & Tự Động Nâng Cấp (Upgrade Helper)
# Tuân thủ nghiêm ngặt GitLab Official Upgrade Path
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

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

echo "================================================================="
echo "  🚀 TRÌNH HỖ TRỢ NÂNG CẤP GITLAB CE THEO LỘ TRÌNH (UPGRADE PATH)"
echo "  Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================="

# 1. Kiểm tra Background Migrations trước
echo ""
echo "🔍 [Bước 1] Kiểm tra trạng thái Background Migrations..."
bash "${SCRIPT_DIR}/check-migrations.sh"

# 2. Khuyến nghị Backup
echo ""
echo "🛡️  [Bước 2] Kiểm tra bản sao lưu an toàn (Backup)..."
LATEST_BACKUP="$(ls -t "${ROOT_DIR}/backups"/gitlab_full_backup_*.tar.gz 2>/dev/null | head -1 || true)"
if [ -n "${LATEST_BACKUP}" ]; then
    echo "   ✅ Đã có bản backup gần nhất: $(basename "${LATEST_BACKUP}") ($(du -h "${LATEST_BACKUP}" | cut -f1))"
else
    echo "   ⚠️  Chưa có bản backup toàn diện nào trong thư mục ./backups/"
fi

read -rp "👉 Bạn có muốn chạy 'make backup-all' trước khi nâng cấp không? (Y/n): " RUN_BACKUP
if [[ "$RUN_BACKUP" =~ ^[Yy]$ ]] || [ -z "$RUN_BACKUP" ]; then
    bash "${SCRIPT_DIR}/backup-all.sh"
fi

# 3. Hiển thị lộ trình nâng cấp chuẩn
CURRENT_VER="${GITLAB_CE_VERSION:-18.11.3-ce.0}"
echo ""
echo "================================================================="
echo "  📋 LỘ TRÌNH NÂNG CẤP BẢO MẬT CHUẨN CỦA GITLAB (TỪ 18.11.3 -> 19.2.4):"
echo "================================================================="
echo "   [Hiện tại] : ${CURRENT_VER}"
echo "   [Bước 1]   : 19.0.8-ce.0 (Điểm dừng bắt buộc Major 19 + Vá bảo mật)"
echo "   [Bước 2]   : 19.2.4-ce.0 (Phiên bản đích mới nhất & an toàn nhất)"
echo "================================================================="
echo ""
echo "👉 Chọn phiên bản bạn muốn nâng cấp lên trong bước này:"
echo "   1) 19.0.8-ce.0 (Khuyên dùng cho Bước 1 - Điểm dừng Major 19)"
echo "   2) 19.2.4-ce.0 (Khuyên dùng cho Bước 2 - Bản mới nhất khuyến nghị)"
echo "   3) 19.1.6-ce.0"
echo "   4) Nhập phiên bản tùy chỉnh (Custom Tag)"
echo "   5) Hủy bỏ (Thoát)"
echo ""
read -rp "Chọn số (1-5): " CHOICE

case "$CHOICE" in
    1) TARGET_VERSION="19.0.8-ce.0" ;;
    2) TARGET_VERSION="19.2.4-ce.0" ;;
    3) TARGET_VERSION="19.1.6-ce.0" ;;
    4) read -rp "Nhập tag GitLab CE (ví dụ: 19.2.4-ce.0): " TARGET_VERSION ;;
    *) echo "❌ Đã hủy quá trình nâng cấp."; exit 0 ;;
esac

echo ""
echo "🎯 Phiên bản đích được chọn: ${TARGET_VERSION}"
read -rp "👉 Xác nhận nâng cấp lên ${TARGET_VERSION}? (y/N): " CONFIRM_UPGRADE
if [[ ! "$CONFIRM_UPGRADE" =~ ^[Yy]$ ]]; then
    echo "❌ Đã hủy thao tác."
    exit 0
fi

# 4. Cập nhật file .env
echo ""
echo "⚙️  [Bước 3] Đang cập nhật GITLAB_CE_VERSION trong .env..."
if [ -f .env ]; then
    sed -i "s/^GITLAB_CE_VERSION=.*/GITLAB_CE_VERSION=${TARGET_VERSION}/" .env
else
    cp .env.default .env
    sed -i "s/^GITLAB_CE_VERSION=.*/GITLAB_CE_VERSION=${TARGET_VERSION}/" .env
fi
echo "   ✅ Đã cập nhật .env: GITLAB_CE_VERSION=${TARGET_VERSION}"

# 5. Pull image mới và Restart
echo ""
echo "📥 [Bước 4] Đang pull image gitlab/gitlab-ce:${TARGET_VERSION}..."
docker compose pull gitlab

echo ""
echo "🔄 [Bước 5] Đang khởi động lại GitLab với phiên bản mới..."
docker compose up -d gitlab

echo ""
echo "⏳ Đang theo dõi trạng thái khởi động của GitLab..."
echo "   Quá trình Database Migrations có thể mất từ 2-5 phút..."
echo "   (Nhấn Ctrl+C bất kỳ lúc nào nếu muốn thoát chế độ xem logs)"
echo ""
sleep 10
docker compose logs -f gitlab --tail=50
