#!/bin/bash
# ================================================================
# Wrapper script gọi sinh SSL cho Outline service từ root repository
# Domain: outline.cloudsb.space
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTLINE_DIR="${SCRIPT_DIR}/../outline"

if [ -f "${OUTLINE_DIR}/scripts/generate-ssl.sh" ]; then
    bash "${OUTLINE_DIR}/scripts/generate-ssl.sh"
else
    echo "❌ Không tìm thấy script tại ${OUTLINE_DIR}/scripts/generate-ssl.sh"
    exit 1
fi
