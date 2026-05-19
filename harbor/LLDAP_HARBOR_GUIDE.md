# Hướng dẫn tích hợp LLDAP với Harbor Container Registry

Tài liệu này hướng dẫn chi tiết cách cấu hình xác thực người dùng trong **Harbor** thông qua **LLDAP** server được triển khai tại `172.23.1.18`.

---

## 1. Cơ chế hoạt động của Harbor với LDAP
Do Harbor lưu trữ thông tin cấu hình và phân quyền hệ thống trong cơ sở dữ liệu Postgres nội bộ của nó, Harbor không hỗ trợ khai báo cấu hình LDAP trực tiếp thông qua file Compose/YAML cấu hình tĩnh.

Thay vào đó, bạn sẽ cấu hình một lần duy nhất qua giao diện Web UI với quyền `admin`. Sau đó, toàn bộ tài khoản người dùng từ LLDAP có thể đăng nhập trực tiếp.

---

## 2. Bảng cấu hình chi tiết trên Harbor UI

Đăng nhập vào Harbor Web UI với tài khoản `admin` -> đi tới menu **Administration** -> **Configuration** -> Chọn tab **Authentication**.

Thiết lập các thông số chính xác theo bảng sau:

| Tên trường trên Harbor UI | Giá trị cấu hình | Giải thích chi tiết |
| :--- | :--- | :--- |
| **Auth Mode** | `LDAP` | Chuyển chế độ đăng nhập sang LDAP. |
| **LDAP URL** | `ldap://172.23.1.18:3890` | Địa chỉ và cổng LDAP của LLDAP. |
| **LDAP Search DN** | `uid=admin,ou=people,dc=example,dc=com` | Tài khoản bind (admin của LLDAP) dùng để search user. |
| **LDAP Search Password** | *(Mật khẩu admin LLDAP của bạn)* | Mật khẩu của tài khoản bind ở trên. |
| **LDAP Base DN** | `ou=people,dc=example,dc=com` | Nơi tìm kiếm thông tin tài khoản người dùng. |
| **LDAP Filter** | `(objectClass=person)` | Chỉ cho phép các object class person đăng nhập. |
| **LDAP UID** | `uid` | Thuộc tính định danh duy nhất của LLDAP. |
| **LDAP Scope** | `Subtree` | Tìm kiếm sâu xuống các nhánh con. |

### Cấu hình ánh xạ Nhóm (LDAP Group Settings) - Tùy chọn
Nếu bạn muốn phân quyền dự án trong Harbor theo các Group của LLDAP, cấu hình các dòng sau:

*   **LDAP Group Base DN:** `ou=groups,dc=example,dc=com`
*   **LDAP Group Filter:** `(objectClass=groupOfUniqueNames)`
*   **LDAP Group GID:** `cn`
*   **LDAP Group Membership:** `member`

---

## 3. Các bước kiểm tra và áp dụng

1. **Test Connection:** Nhấp vào nút **"TEST LDAP SERVER"** ở dưới cùng.
   - Nếu hiển thị thông báo **Success / Kết nối thành công**: Cấu hình của bạn hoàn toàn chính xác.
   - Nếu báo lỗi: Hãy kiểm tra xem Harbor host có ping thông tới IP `172.23.1.18` qua cổng `3890` hay không, hoặc kiểm tra lại Bind DN & Password.
2. **Save:** Nhấp nút **SAVE** để lưu lại cấu hình.

---

## 4. Lưu ý quan trọng
- Khi đã chuyển sang **Auth Mode: LDAP**, Harbor sẽ khóa chức năng tạo User thủ công trên giao diện. Mọi hoạt động quản lý User (tạo mới, đổi mật khẩu, v.v.) sẽ do **LLDAP** đảm nhiệm.
- Tài khoản cục bộ mặc định `admin` vẫn có thể đăng nhập song song để quản trị hệ thống Harbor.
