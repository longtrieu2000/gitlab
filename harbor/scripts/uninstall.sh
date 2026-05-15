#!/bin/bash
# ================================================================
# Harbor Uninstall / Cleanup Script
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
INSTALLER_DIR="${PROJECT_DIR}/harbor-installer"

cd "${PROJECT_DIR}"

if [ -f .env ]; then
    source .env
elif [ -f .env.default ]; then
    source .env.default
fi

HARBOR_DATA_DIR="${HARBOR_DATA_DIR:-/data/harbor}"

echo "================================================"
echo "  Harbor Cleanup"
echo "================================================"

# Stop containers
if [ -d "${INSTALLER_DIR}" ] && [ -f "${INSTALLER_DIR}/docker-compose.yml" ]; then
    echo "🛑 Stopping Harbor containers..."
    cd "${INSTALLER_DIR}"
    docker compose down -v 2>/dev/null || true
    cd "${PROJECT_DIR}"
fi

echo ""
echo "⚠️  Xoá data? Hành động này KHÔNG THỂ HOÀN TÁC!"
echo "    Data dir: ${HARBOR_DATA_DIR}"
read -p "    Nhập 'yes' để xác nhận: " confirm

if [ "$confirm" = "yes" ]; then
    echo "🗑️  Xoá data directory..."
    sudo rm -rf "${HARBOR_DATA_DIR}"
    echo "  ✅ Đã xoá ${HARBOR_DATA_DIR}"
else
    echo "  ⏭️  Giữ nguyên data directory"
fi

echo ""
echo "✅ Harbor cleanup hoàn tất"
