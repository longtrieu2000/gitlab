#!/bin/bash
# ================================================================
# Setup Script cho Outline MCP Server
# Dành cho các thành viên trong Team NetSecOps
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "================================================================="
echo "  🚀 CÀI ĐẶT OUTLINE MCP SERVER CHO CLIENT / IDE"
echo "  Outline URL: https://outline.cloudsb.space"
echo "================================================================="

# 1. Kiểm tra Python 3
if ! command -v python3 &>/dev/null; then
    echo "❌ Lỗi: Máy tính chưa cài đặt Python 3. Vui lòng cài đặt Python >= 3.10."
    exit 1
fi

echo "🐍 Đang kiểm tra phiên bản Python: $(python3 --version)"

# 2. Cài đặt mcp-outline package
echo ""
echo "📦 [1/3] Đang cài đặt package mcp-outline..."
python3 -m pip install --user --upgrade mcp-outline

# Tìm đường dẫn binary mcp-outline
MCP_BIN="$(which mcp-outline 2>/dev/null || true)"
if [ -z "${MCP_BIN}" ]; then
    if [ -f "${HOME}/.local/bin/mcp-outline" ]; then
        MCP_BIN="${HOME}/.local/bin/mcp-outline"
    fi
fi

if [ -n "${MCP_BIN}" ]; then
    echo "   ✅ Đã tìm thấy binary mcp-outline tại: ${MCP_BIN}"
else
    echo "   ⚠️  Không tìm thấy trong PATH, sẽ sử dụng lệnh: python3 -m mcp_outline"
    MCP_BIN="python3 -m mcp_outline"
fi

# 3. Kiểm tra kết nối tới Outline API
echo ""
echo "🔍 [2/3] Kiểm tra kết nối tới Outline instance (outline.cloudsb.space)..."
API_KEY="ol_api_R7TvuW9cfEtCDVH2GuygGM9Kyb0MZ2KaA7jxLi"
CHECK_STATUS=$(python3 -c "
import urllib.request, json, ssl
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

req = urllib.request.Request(
    'https://outline.cloudsb.space/api/auth.info',
    data=b'{}',
    headers={
        'Authorization': 'Bearer ${API_KEY}',
        'Content-Type': 'application/json'
    }
)
try:
    with urllib.request.urlopen(req, context=ctx) as res:
        data = json.loads(res.read().decode())
        print('SUCCESS:' + data.get('data', {}).get('user', {}).get('name', 'Unknown'))
except Exception as e:
    print('ERROR:' + str(e))
")

if [[ "${CHECK_STATUS}" == SUCCESS* ]]; then
    USER_NAME="${CHECK_STATUS#SUCCESS:}"
    echo "   🎉 Kết nối thành công! Xác thực tài khoản: ${USER_NAME}"
else
    echo "   ❌ Lỗi kết nối tới Outline: ${CHECK_STATUS}"
fi

# 4. Hướng dẫn cấu hình vào các IDE / Tools
echo ""
echo "📝 [3/3] Xuất cấu hình MCP cho các IDE:"
echo "-----------------------------------------------------------------"
echo "👉 1. Antigravity IDE:"
echo "   Copy nội dung file mcp_config.json vào ~/.gemini/config/mcp_config.json"
echo ""
echo "👉 2. Claude Desktop:"
echo "   - macOS: ~/Library/Application Support/Claude/claude_desktop_config.json"
echo "   - Windows: %APPDATA%/Claude/claude_desktop_config.json"
echo "   - Linux: ~/.config/Claude/claude_desktop_config.json"
echo ""
echo "👉 3. Cursor AI:"
echo "   Settings -> Features -> MCP -> Add new MCP server -> Chọn command: mcp-outline"
echo "-----------------------------------------------------------------"
echo "🎉 HOÀN TẤT THIẾT LẬP!"
