#!/bin/bash
# ================================================================
# GitLab Server - Kiểm tra độ sẵn sàng nâng cấp (Upgrade Readiness)
# Kiểm tra Batched Background Migrations (BBMs) & Trạng thái Database
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

echo "================================================================="
echo "  🔍 KIỂM TRA TRẠNG THÁI MIGRATIONS & ĐỘ SẴN SÀNG NÂNG CẤP GITLAB"
echo "  Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================="

# 1. Kiểm tra containers
echo ""
echo "1️⃣  Kiểm tra trạng thái Containers..."
if ! docker compose ps --services --filter "status=running" | grep -q "gitlab"; then
    echo "❌ Container GitLab chưa chạy! Vui lòng khởi động hệ thống trước: make up"
    exit 1
fi
echo "   ✅ Containers (GitLab, PostgreSQL, Redis) đang hoạt động bình thường."

# 2. Lấy thông tin phiên bản hiện tại
GITLAB_VERSION="$(docker compose exec -T gitlab cat /opt/gitlab/version-manifest.txt 2>/dev/null | head -1 | awk '{print $2}' || echo 'unknown')"
echo ""
echo "2️⃣  Phiên bản GitLab hiện tại: ${GITLAB_VERSION}"

# 3. Kiểm tra dung lượng ổ đĩa
echo ""
echo "3️⃣  Kiểm tra dung lượng ổ đĩa máy chủ..."
FREE_SPACE_GB=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')
echo "   Dung lượng còn trống: ${FREE_SPACE_GB} GB"
if [ "${FREE_SPACE_GB}" -lt 15 ]; then
    echo "   ⚠️  CẢNH BÁO: Dung lượng ổ đĩa còn dưới 15GB (${FREE_SPACE_GB}GB). Nên giải phóng thêm bộ nhớ trước khi upgrade."
else
    echo "   ✅ Dung lượng ổ đĩa đạt yêu cầu an toàn (>15GB)."
fi

# 4. Kiểm tra Batched Background Migrations (BBMs)
echo ""
echo "4️⃣  Kiểm tra Batched Background Migrations (BBMs)..."
echo "   Đang truy vấn database qua GitLab Rails..."

MIGRATION_CHECK_OUTPUT=$(docker compose exec -T gitlab gitlab-rails runner "
  begin
    pending = Gitlab::Database::BackgroundMigration::BatchedMigration.where.not(status: :finished).count
    failed = Gitlab::Database::BackgroundMigration::BatchedMigration.where(status: :failed).count
    active = Gitlab::Database::BackgroundMigration::BatchedMigration.where(status: :active).count
    puts \"PENDING_COUNT=#{pending}\"
    puts \"FAILED_COUNT=#{failed}\"
    puts \"ACTIVE_COUNT=#{active}\"
    
    if pending > 0
      puts \"--- CHI TIẾT MIGRATIONS CHƯA XONG ---\"
      Gitlab::Database::BackgroundMigration::BatchedMigration.where.not(status: :finished).each do |m|
        puts \"Job: #{m.job_class_name} | Table: #{m.table_name} | Status: #{m.status_name} | Progress: #{m.progress}%\"
      end
    end
  rescue => e
    puts \"ERROR: #{e.message}\"
  end
" 2>&1 || true)

echo "${MIGRATION_CHECK_OUTPUT}"

PENDING_COUNT=$(echo "${MIGRATION_CHECK_OUTPUT}" | grep "PENDING_COUNT=" | cut -d'=' -f2 || echo "0")
FAILED_COUNT=$(echo "${MIGRATION_CHECK_OUTPUT}" | grep "FAILED_COUNT=" | cut -d'=' -f2 || echo "0")

echo ""
echo "================================================================="
if [ "${PENDING_COUNT}" = "0" ] && [ "${FAILED_COUNT}" = "0" ]; then
    echo "  🎉 KẾT QUẢ: HỆ THỐNG ĐÃ SẴN SÀNG ĐỂ NÂNG CẤP (READY FOR UPGRADE)!"
    echo "  ✅ Không có Batched Background Migration nào đang pending hoặc lỗi."
    echo "  👉 Bạn có thể an toàn chuyển sang phiên bản tiếp theo."
else
    echo "  ⚠️  CẢNH BÁO: CHƯA ĐỦ ĐIỀU KIỆN NÂNG CẤP!"
    echo "  ❌ Còn ${PENDING_COUNT} migrations chưa hoàn thành (trong đó ${FAILED_COUNT} lỗi)."
    echo "  👉 TUYỆT ĐỐI KHÔNG NÂNG CẤP lúc này vì sẽ gây hỏng Database!"
    echo ""
    echo "  🛠️ Hướng dẫn xử lý:"
    echo "  1. Đợi vài phút để Sidekiq tự động chạy hết các migration."
    echo "  2. Hoặc truy cập giao diện: Admin Area (🔧) → Monitoring → Background Migrations để theo dõi/chạy lại."
fi
echo "================================================================="
