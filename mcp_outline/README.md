# Outline MCP Server - Hướng Dẫn Tích Hợp Cho Team

Gói cấu hình và công cụ kết nối **Model Context Protocol (MCP)** tới hệ thống tri thức **Outline Wiki** (`https://outline.cloudsb.space`) của Team NetSecOps.

---

## 📁 Cấu Trúc Thư Mục `mcp_outline/`

```text
mcp_outline/
├── setup.sh                     # Script cài đặt tự động 1-click
├── mcp_config.json              # File cấu hình chuẩn cho Antigravity IDE
├── claude_desktop_config.json   # File cấu hình cho Claude Desktop
├── cursor_config.json           # File cấu hình cho Cursor AI
├── .env.example                 # File biến môi trường mẫu
├── schemas/                     # 39 file JSON định nghĩa schema của tất cả các MCP tools
└── README.md                    # Tài liệu hướng dẫn này
```

---

## 🚀 1. Cài Đặt Nhanh (1-Click Setup)

Mở Terminal trong thư mục này và chạy:

```bash
bash setup.sh
```

Script sẽ tự động:
1. Cài đặt package `mcp-outline` qua pip.
2. Kiểm tra xác thực API Key và kết nối tới `https://outline.cloudsb.space`.
3. In ra vị trí đặt file config cho từng loại IDE/trợ lý AI.

---

## ⚙️ 2. Hướng Dẫn Cấu Hình Cho Từng Ứng Dụng

### A. Antigravity IDE (Google DeepMind)
1. Mở file: `~/.gemini/config/mcp_config.json`
2. Thêm block sau vào trong `"mcpServers"`:

```json
{
  "mcpServers": {
    "outline": {
      "command": "/home/YOUR_USER/.local/bin/mcp-outline",
      "args": [],
      "env": {
        "OUTLINE_API_KEY": "ol_api_R7TvuW9cfEtCDVH2GuygGM9Kyb0MZ2KaA7jxLi",
        "OUTLINE_API_URL": "https://outline.cloudsb.space",
        "OUTLINE_BASE_URL": "https://outline.cloudsb.space"
      }
    }
  }
}
```

---

### B. Claude Desktop
Mở file `claude_desktop_config.json`:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

Dán cấu hình sau:
```json
{
  "mcpServers": {
    "outline": {
      "command": "mcp-outline",
      "args": [],
      "env": {
        "OUTLINE_API_KEY": "ol_api_R7TvuW9cfEtCDVH2GuygGM9Kyb0MZ2KaA7jxLi",
        "OUTLINE_API_URL": "https://outline.cloudsb.space",
        "OUTLINE_BASE_URL": "https://outline.cloudsb.space"
      }
    }
  }
}
```

---

### C. Cursor AI / VS Code Roo / Cline
1. Vào **Cursor Settings** ➜ **Features** ➜ **MCP**.
2. Bấm **Add New MCP Server**.
3. Điền thông tin:
   - **Name**: `outline`
   - **Type**: `command`
   - **Command**: `mcp-outline`
   - **Environment Variables**:
     - `OUTLINE_API_KEY`: `ol_api_R7TvuW9cfEtCDVH2GuygGM9Kyb0MZ2KaA7jxLi`
     - `OUTLINE_API_URL`: `https://outline.cloudsb.space`

---

## 🛠️ 3. Danh Sách Các Công Cụ MCP Hỗ Trợ (Tools)

| Công cụ | Mô tả chức năng |
| :--- | :--- |
| `list_collections` | Liệt kê tất cả các collections trong Outline |
| `get_collection_structure` | Xem cây cấu trúc tài liệu phân cấp trong một collection |
| `read_document` | Đọc toàn bộ nội dung tài liệu theo Document ID |
| `search_documents` | Tìm kiếm tài liệu theo từ khóa hoặc tiêu đề |
| `search_document_content` | Tìm kiếm sâu bên trong nội dung văn bản của tài liệu |
| `create_document` | Tạo tài liệu mới (Markdown) trong collection chỉ định |
| `edit_document` / `update_document` | Chỉnh sửa, cập nhật nội dung tài liệu |
| `archive_document` / `delete_document` | Lưu trữ hoặc xóa tài liệu |
| `list_document_comments` / `add_comment` | Đọc và thêm bình luận vào tài liệu |
| `fetch_attachment` / `get_attachment_url` | Tải và xem link file đính kèm/hình ảnh trong tài liệu |

---

## 💡 Ví Dụ Prompt Mẫu
- *"Tìm kiếm trong Outline các bài viết về OVS upcall thread"*
- *"Đọc nội dung tài liệu 'Ukey' trong collection Revalidator"*
- *"Tạo tài liệu mới tên 'Hướng dẫn vận hành' vào collection Cloud VPC Flow Log"*
