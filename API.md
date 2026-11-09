# MyFAP API Express Mongoose

Base URL: `http://localhost:3000/api`. Android emulator: `http://10.0.2.2:3000/api`. Ngoài health/login, cần `Authorization: Bearer <accessToken>`. ID là chuỗi MongoDB ObjectId 24 ký tự hex, lấy trường `id` từ response, không dùng ID số cũ. `slot_id` vẫn là số 1–4; `version` bắt đầu 0, luôn đọc bản mới nhất trước khi ghi.

| Method | Đường dẫn | Quyền / ý nghĩa |
|---|---|---|
| GET | /health | Công khai, xác minh kết nối MongoDB |
| POST | /auth/login | Công khai, cấp token phiên |
| GET | /auth/me | Tài khoản hiện tại |
| POST | /auth/logout | Thu hồi token, trả 204 |
| POST | /users | STAFF cấp tài khoản |
| GET/POST | /departments | Mọi role đọc; STAFF tạo bộ môn |
| GET/POST | /courses | Mọi role đọc; STAFF tạo môn |
| GET/POST | /semesters | Mọi role đọc; STAFF tạo kỳ |
| GET/POST | /rooms | Mọi role đọc; STAFF tạo phòng |
| GET | /time-slots | 4 slot cố định, giờ Việt Nam |
| GET | /sections | STUDENT các lớp đã đăng ký; LECTURER lớp phụ trách; HEAD bộ môn; STAFF toàn trường |
| GET | /sections/available?course_id=...&semester_id=... | STUDENT/STAFF; lớp mở có lịch tương lai, enrolled/remaining; lớp đầy vẫn hiện remaining=0 |
| POST | /sections | STAFF tạo lớp 30 chỗ |
| PATCH | /sections/:id/status | STAFF mở/đóng đăng ký |
| GET | /sections/:id/sessions | Xem lịch lớp trước khi đăng ký; STUDENT không nhận danh sách điểm danh |
| GET | /sections/:id/enrollments | Theo phạm vi; STUDENT chỉ dòng của mình |
| POST | /sections/:id/enrollments | STUDENT tự đăng ký; STAFF đăng ký thay |
| POST | /sections/:id/enrollments/:studentId/withdraw | STUDENT tự rút; STAFF rút thay |
| GET | /me/enrollments | STUDENT xem đăng ký hiện tại và đã rút |
| GET | /schedule?from=...&to=... | Lịch đúng phạm vi, tối đa 93 ngày/1000 buổi; không trả danh sách điểm danh |
| POST | /sessions | STAFF xếp buổi theo ngày + slot |
| PATCH | /sessions/:id/schedule | STAFF đổi lịch trực tiếp hoặc chuẩn hóa buổi cũ còn ở tương lai |
| PATCH | /sessions/:id/status | STAFF đặt COMPLETED/CANCELLED |
| GET | /sessions/:id/history | LECTURER phụ trách / HEAD bộ môn / STAFF xem lịch sử lịch |
| GET | /sessions/:id/attendance | Đúng phạm vi, STUDENT chỉ dữ liệu bản thân |
| PUT | /sessions/:id/attendance | LECTURER phụ trách, đủ danh sách của buổi |
| GET | /sessions/:id/attendance-history | LECTURER/HEAD/STAFF đúng phạm vi, snapshot trước/sau |
| POST | /leave-requests | STUDENT gửi nghỉ đúng buổi/ngày/slot |
| GET | /leave-requests?status=PENDING&page=1 | Theo phạm vi vai trò |
| PATCH | /leave-requests/:id/decision | LECTURER phụ trách duyệt/từ chối |
| POST | /change-requests | LECTURER phụ trách gửi đổi lịch/phòng |
| GET | /change-requests?status=PENDING&page=1 | LECTURER xem của mình; HEAD bộ môn; STAFF tất cả |
| PATCH | /change-requests/:id/decision | STAFF duyệt, cập nhật lịch nguyên tử |
| GET | /department/summary?semester_id=... | HEAD thống kê bộ môn tài khoản, không có điểm |

List đơn có 50 dòng/trang, page mặc định 1. Danh mục/lớp tối đa 200, lịch và lịch lớp tối đa 1000; history tối đa 200. Đây là giới hạn MVP, chưa có phân trang đầy đủ cho các list ngoài đơn.

## Payload

Các ID mẫu bên dưới chỉ minh họa; thay bằng id nhận từ GET/POST tương ứng.

Đăng nhập:
```json
{"email":"student@myfap.local","password":"Demo@12345678"}
```
Trả `accessToken`, `expiresAt`, `user`. Token chỉ lưu hash trong DB; hạn mặc định 8 giờ. Không có đăng ký tài khoản công khai.

Cấp tài khoản:
```json
{"user_code":"HE200002","name":"Sinh viên Hai","email":"student2@myfap.local","password":"NewDemo@12345678","role":"STUDENT","department_id":"507f1f77bcf86cd799439011"}
```
Bộ môn: `{"code":"SE","name":"Kỹ thuật phần mềm"}`.

Môn: `{"code":"PRM393","name":"Flutter Mobile","department_id":"507f1f77bcf86cd799439011"}`.

Kỳ: `{"code":"SPRING2027","name":"Xuân 2027","start_at":"2027-01-01T00:00:00+07:00","end_at":"2027-05-01T00:00:00+07:00"}`.

Phòng: `{"name":"BE-303","capacity":30}`.

Tạo lớp:
```json
{"code":"SE20B-PRM393","course_id":"507f1f77bcf86cd799439012","semester_id":"507f1f77bcf86cd799439013","lecturer_id":"507f1f77bcf86cd799439014"}
```
Không gửi capacity; server cố định 30. Bộ môn suy ra từ môn học và đối chiếu giảng viên. Mã lớp được dùng lại ở học kỳ khác. Đóng/mở đăng ký: `{"version":0,"status":"CLOSED"}` hoặc OPEN.

Tạo buổi, thay ngày phù hợp học kỳ và tương lai:
```json
{"section_id":"507f1f77bcf86cd799439015","room_id":"507f1f77bcf86cd799439016","session_date":"2027-01-15","slot_id":1}
```
Server tự tính start_at/end_at UTC từ giờ Việt Nam. Slot 1: 07:30–09:50; slot 2: 10:00–12:20; slot 3: 12:50–15:10; slot 4: 15:20–17:40. Không nhận start_at/end_at tự do.

Sinh viên đăng ký: body `{}`. STAFF đăng ký thay: `{"student_id":"507f1f77bcf86cd799439017"}`. Rút lớp: `{"version":0}`; version lấy từ /me/enrollments hoặc list đăng ký. Lớp chưa có lịch, lớp đủ, trùng môn cùng kỳ hoặc trùng lịch đều trả 409.

Gửi nghỉ:
```json
{"session_id":"507f1f77bcf86cd799439018","reason":"Có lịch khám bệnh"}
```
Backend chụp ngày/slot hiện tại, client không tự ghi ngày/slot của đơn. Một buổi/sinh viên chỉ có một đơn PENDING hoặc APPROVED. INVALIDATED/REJECTED/CANCELLED vẫn lưu lịch sử và cho phép gửi đơn mới khi buổi còn tương lai.

Duyệt đơn nghỉ/đổi lịch:
```json
{"version":0,"decision":"APPROVED","note":"Đồng ý"}
```
Từ chối dùng REJECTED; note bắt buộc. Chỉ đơn PENDING được xử lý. HEAD không được duyệt.

Gửi đổi lịch/phòng:
```json
{"session_id":"507f1f77bcf86cd799439018","reason":"Phòng bảo trì","proposed_room_id":"507f1f77bcf86cd799439019","proposed_date":"2027-01-15","proposed_slot_id":2}
```
Đổi phòng giữ ngày/slot; đổi slot giữ phòng nếu phù hợp. Kiểm tra trùng lại khi STAFF duyệt. Đổi ngày/slot làm đơn nghỉ cũ INVALIDATED; không tự duyệt lại. Sinh viên phải gửi đơn mới.

STAFF đổi lịch trực tiếp:
```json
{"version":0,"room_id":"507f1f77bcf86cd799439019","session_date":"2027-01-15","slot_id":2,"reason":"Điều chỉnh lịch"}
```
Đặt trạng thái buổi: `{"version":0,"status":"CANCELLED","reason":"Nghỉ học"}` hoặc COMPLETED sau giờ kết thúc.

Điểm danh:
```json
{"version":0,"rows":[{"student_id":"507f1f77bcf86cd799439017","status":"ABSENT"}]}
```
Gửi đủ danh sách của buổi, không chỉ người vắng. Status: PRESENT/ABSENT/LATE/EXCUSED. GET attendance trả:
```json
{"version":1,"saved":true,"session_status":"COMPLETED","rows":[{"student_id":"507f1f77bcf86cd799439017","user_code":"HE200002","name":"Sinh viên Hai","status":"ABSENT","approved_leave_id":"507f1f77bcf86cd799439020","note":"Nghỉ có phép"}]}
```
Chưa ghi: status NOT_RECORDED. Note là giá trị suy ra từ đơn APPROVED còn đúng lịch, không nhận note do sinh viên tự ghi. Khi bị INVALIDATED, note biến mất.

## Lỗi

400 payload/ID/JSON sai; 401 đăng nhập sai hoặc phiên hết hạn/thu hồi; 403 sai quyền/phạm vi; 404 không có bản ghi; 409 lớp đủ/trùng lịch/dữ liệu trùng/version cũ/sai trạng thái; 413 JSON >64 KiB; 429 vượt giới hạn; 500 lỗi máy chủ. JSON lỗi dạng `{"message":"..."}`, validation có thêm issues. Không trả stack trace, password_hash hoặc token_hash.
