# MyFAP API

Base URL trên máy: `http://localhost:3000/api`; Android emulator: `http://10.0.2.2:3000/api`. Ngoài health/login, mọi API yêu cầu `Authorization: Bearer <accessToken>`. JSON dùng snake_case cho dữ liệu học vụ; phản hồi login dùng `accessToken`, `expiresAt`.

| Method | Đường dẫn | Vai trò / kết quả |
|---|---|---|
| GET | /health | Công khai; kết nối DB |
| POST | /auth/login | Công khai; cấp phiên |
| GET | /auth/me | Mọi vai trò; thông tin tài khoản |
| POST | /auth/logout | Mọi vai trò; 204 |
| POST | /users | STAFF; cấp tài khoản |
| GET | /rooms | Mọi vai trò; tối đa 200 phòng |
| POST | /rooms | STAFF; tạo phòng |
| GET | /sections | Theo phạm vi vai trò; tối đa 200 lớp |
| POST | /sections | STAFF; tạo lớp |
| POST | /sections/:id/enrollments | STAFF; thêm sinh viên trước khi xếp lịch |
| GET | /schedule?from=...&to=... | Lịch cá nhân/bộ môn/toàn trường; tối đa 93 ngày, 1000 buổi |
| POST | /sessions | STAFF; xếp buổi học |
| GET | /sessions/:id/attendance | Đúng phạm vi; sinh viên chỉ nhận dòng của mình |
| PUT | /sessions/:id/attendance | Giảng viên phụ trách; cập nhật đủ lớp |
| POST | /leave-requests | STUDENT; gửi đơn nghỉ |
| GET | /leave-requests?status=PENDING&page=1 | Theo phạm vi; 50 dòng/trang |
| PATCH | /leave-requests/:id/decision | Giảng viên phụ trách duyệt |
| POST | /change-requests | Giảng viên phụ trách đề xuất đổi lịch/phòng |
| GET | /change-requests?status=PENDING&page=1 | LECTURER xem của mình; HEAD trong bộ môn; STAFF tất cả |
| PATCH | /change-requests/:id/decision | STAFF duyệt; chấp thuận cập nhật lịch nguyên tử |
| GET | /department/summary | HEAD; thống kê lịch/điểm danh bộ môn tài khoản |

Các list đơn nhận status tùy chọn: PENDING, APPROVED, REJECTED. `page` mặc định 1. API không nhận department/user tùy ý để mở rộng phạm vi truy cập. ID số nguyên dương, version bắt đầu 0. Đọc version hiện tại từ danh sách đơn hoặc GET attendance trước khi cập nhật. Nếu danh sách chạm giới hạn 200/1000, thu hẹp dữ liệu trước khi mở rộng hệ thống; chưa có phân trang danh mục/lịch.

## Payload mẫu

Đăng nhập:
```json
{"email":"student@myfap.local","password":"Demo@12345678"}
```
Phản hồi: `{"accessToken":"...","expiresAt":"...Z","user":{"id":1,"name":"...","email":"...","role":"STUDENT","department":"SE","active":1}}`.

STAFF cấp tài khoản (không nhận trường active hoặc password_hash từ client):
```json
{"name":"Sinh viên Hai","email":"student2@myfap.local","password":"NewDemo@12345678","role":"STUDENT","department":"SE"}
```
Tạo phòng:
```json
{"name":"BE-303","capacity":40}
```
Tạo lớp:
```json
{"code":"SE20B-PRM393","course":"Flutter Mobile","department":"SE","lecturer_id":2}
```
Thêm sinh viên `POST /sections/2/enrollments`:
```json
{"student_id":1}
```
Tạo buổi học (thay ngày tương lai phù hợp thời điểm chạy):
```json
{"section_id":1,"room_id":1,"start_at":"2026-12-01T01:00:00Z","end_at":"2026-12-01T03:00:00Z"}
```
Gửi đơn nghỉ:
```json
{"session_id":2,"reason":"Có lịch khám bệnh"}
```
Duyệt đơn nghỉ hoặc đổi lịch:
```json
{"version":0,"decision":"APPROVED","note":"Đồng ý theo đề nghị"}
```
Từ chối dùng `decision: "REJECTED"`; note bắt buộc. Chỉ PENDING được xử lý; không được duyệt lại.

Đề nghị đổi lịch/phòng:
```json
{"session_id":2,"reason":"Phòng đang bảo trì","proposed_room_id":2,"proposed_start":"2026-12-01T01:00:00Z","proposed_end":"2026-12-01T03:00:00Z"}
```
Đổi phòng giữ start/end hiện tại; đổi giờ giữ room hiện tại. Cần gửi cả ba trường proposed.

Lưu điểm danh (gửi tất cả sinh viên, không chỉ những người vắng):
```json
{"version":0,"rows":[{"student_id":1,"status":"ABSENT"}]}
```
GET attendance trả:
```json
{"version":1,"saved":true,"rows":[{"student_id":1,"name":"Demo STUDENT","email":"student@myfap.local","status":"ABSENT","approved_leave_id":1,"note":"Nghỉ có phép"}]}
```
Nếu chưa ghi: status NOT_RECORDED, saved false. Ghi chú độc lập với status, không do client tùy ý ghi. UI đặt `note` ở cột cạnh trạng thái; có thể hiện nhãn `ABSENT • Nghỉ có phép`.

## Lỗi

400 dữ liệu/ID/JSON sai; 401 chưa đăng nhập, sai mật khẩu, phiên hết hạn/thu hồi; 403 sai quyền/phạm vi; 404 không có bản ghi/API; 409 trùng dữ liệu/lịch, version cũ hoặc sai trạng thái nghiệp vụ; 413 JSON >64 KiB; 429 vượt giới hạn; 500 lỗi nội bộ. Lỗi thường dạng `{"message":"..."}`; 400 validation có thêm issues. Middleware giới hạn tần suất có thể trả text, Flutter đã xử lý phản hồi không phải JSON.
