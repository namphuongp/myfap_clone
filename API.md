# MyFAP API

Base URL `http://localhost:3000/api`. Android emulator dùng `http://10.0.2.2:3000/api`. Ngoài health/login, cần `Authorization: Bearer <accessToken>`. ID là ObjectId 24 ký tự hex, lấy trường `id` từ response. `version` bắt đầu 0, luôn đọc phiên bản mới trước khi cập nhật. `slot_id` là số 1–4.

## Chức năng HEAD

HEAD có bốn màn hình: Báo cáo bộ môn, Quản lý môn học, Phân công giảng dạy và Gửi đơn chuyển phòng. Không có màn theo dõi chuyên cần từng sinh viên. Bộ môn lấy từ tài khoản đã xác thực, không nhận `department_id` từ client.

### GET /head/options

Chỉ HEAD. Trả `{courses,lecturers,semesters}`. Môn và giảng viên đang hoạt động thuộc bộ môn HEAD; học kỳ chuẩn dùng chung. Giảng viên chỉ có thông tin hiển thị, không trả mật khẩu/token.

### GET /head/courses

Chỉ HEAD. Query `search` tìm chuỗi thường trong mã/tên môn và `page` mặc định 1. Trả `{page,total,has_more,items}`, 50 môn/trang, chỉ trong bộ môn. `GET /courses` của HEAD cũng giới hạn cùng bộ môn.

### POST /head/courses

Chỉ HEAD. Body `{"code":"HEAD101","name":"Học phần mới"}`; backend tự gán bộ môn. Trả 201 cùng `id` và `version`; mã môn duy nhất toàn hệ thống, trùng mã/tên trong bộ môn trả 409. Transaction và audit `HEAD_CREATE_COURSE`. STAFF vẫn tạo môn qua endpoint cũ và quản lý chương trình ngành.

### PATCH /head/courses/:id

Chỉ HEAD cùng bộ môn. Body `{"version":0,"code":"HEAD101","name":"Tên cập nhật"}`. Không đổi bộ môn; mã môn đã có lớp không được thay đổi. Version cũ/trùng mã trả 409; khác bộ môn trả 403. Trả môn với version mới và ghi audit. Không mở API xóa môn.

### GET /head/sections

Chỉ HEAD. Query `page`, `search` theo mã lớp, `semester_id`, `course_id`. Trả `{page,total,has_more,items}`, 50 lớp/trang, có tên/mã môn, tên/mã giảng viên, mã kỳ và `session_count`. Lọc môn ngoài bộ môn trả 403.

### PATCH /head/sections/:id/lecturer

Chỉ HEAD cùng bộ môn. Body `{"version":0,"lecturer_id":"507f1f77bcf86cd799439011"}`. Lớp do STAFF mở trước; giảng viên nhận phân công phải hoạt động và cùng bộ môn. Không đổi khi kỳ đã kết thúc hoặc lớp đã có bất kỳ buổi nào, kể cả buổi hủy. Transaction chung với xếp lịch, kiểm tra version và audit `HEAD_ASSIGN_LECTURER`. STAFF tiếp tục tạo lớp/xếp lịch; các lớp cũ giữ nguyên phân công.

### Báo cáo và chuyển phòng

HEAD dùng `GET /department/summary`, `GET /reports/attendance`, `GET /reports/requests` để xem số liệu tổng hợp trong bộ môn. Không cấp quyền đọc/sửa `/sessions/:id/attendance` hoặc duyệt đơn nghỉ của sinh viên.

HEAD được `GET /schedule?from=...&to=...` trong bộ môn và `GET /rooms`. HEAD gửi `POST /change-requests` theo body hiện có nhưng `proposed_date` và `proposed_slot_id` phải giữ nguyên; thay ngày/ca trả 403. Chỉ buổi tương lai SCHEDULED chưa điểm danh; phòng phải khác phòng cũ, đủ chỗ và không trùng lịch. `GET /change-requests` của HEAD chỉ trả đơn tự gửi cho buổi thuộc bộ môn hiện tại.

Chỉ STAFF được `PATCH /change-requests/:id/decision`. PENDING chưa cập nhật lịch. APPROVED kiểm tra lại version và xung đột, đổi phòng nhưng giữ ngày/ca và đơn nghỉ đã duyệt. REJECTED giữ lịch cũ. Mỗi buổi chỉ một PENDING dùng chung cho HEAD và LECTURER.

## Tài khoản và profile

| Method | Đường dẫn | Quyền |
|---|---|---|
| GET | /health | Công khai; xác minh MongoDB |
| POST | /auth/login | Công khai |
| GET | /auth/me | Mọi role, thông tin bản thân |
| POST | /auth/logout | Mọi role, thu hồi token; 204 |
| GET | /profile | Mọi role, hồ sơ bản thân, tên bộ môn/ngành và đơn chuyển ngành đang chờ hiệu lực |
| PATCH | /profile | Mọi role, chỉ sửa liên hệ bản thân |
| PATCH | /profile/password | Mọi role, đổi mật khẩu và thu hồi mọi phiên |
| POST | /users | STAFF cấp tài khoản |

Login: `{"email":"student@myfap.local","password":"Demo@12345678"}`. Trả accessToken, expiresAt và user; phiên mặc định 8 giờ.

Cập nhật profile:
```json
{"version":1,"phone":"0901234567","address":"Thành phố Hồ Chí Minh","date_of_birth":"2000-01-01"}
```
Các trường liên hệ có thể null để xóa. Không cho đổi name/email/user_code/role/department_id/major_id/active qua profile. Không có trường ảnh hoặc endpoint upload avatar; Flutter dùng chữ cái đầu tên.

Đổi mật khẩu:
```json
{"current_password":"Demo@12345678","new_password":"Changed@12345678"}
```
Mật khẩu mới ít nhất 12 ký tự, tối đa 72 byte UTF-8 và khác mật khẩu cũ. Thành công trả 200, phải đăng nhập lại trên mọi thiết bị. Không có quên mật khẩu/refresh token.

Cấp tài khoản:
```json
{"user_code":"HE200002","name":"Sinh viên Hai","email":"student2@myfap.local","password":"NewDemo@12345678","role":"STUDENT","department_id":"507f1f77bcf86cd799439011","major_id":"507f1f77bcf86cd799439012"}
```
major_id chỉ dành cho STUDENT; bộ môn phải khớp ngành. Có thể cấp tài khoản chưa có ngành, sau đó STAFF gán ngành ban đầu trước khi sinh viên đăng ký môn/chuyển ngành.

## Danh mục, chương trình ngành và học kỳ

| Method | Đường dẫn | Quyền |
|---|---|---|
| GET/POST | /departments | Mọi role đọc; STAFF tạo |
| GET/POST | /courses | Mọi role đọc; STAFF tạo |
| GET/POST | /semesters | Mọi role đọc để chọn kỳ/bộ lọc; STAFF tạo |
| GET/POST | /rooms | STUDENT/LECTURER/STAFF đọc; STAFF tạo |
| GET | /time-slots | STUDENT/LECTURER/STAFF |
| GET | /majors | STUDENT/STAFF xem ngành đang hoạt động |
| POST | /majors | STAFF tạo ngành và danh sách môn |
| PATCH | /majors/:id/curriculum | STAFF cập nhật môn của ngành |
| PATCH | /users/:id/major | STAFF gán ngành ban đầu, chỉ khi sinh viên chưa có ngành |

HEAD chỉ xem báo cáo/profile; GET departments/courses/semesters phục vụ bộ lọc báo cáo. STAFF vẫn có quyền quản trị dữ liệu để vận hành hệ thống.

Bộ môn: `{"code":"SE","name":"Kỹ thuật phần mềm"}`.

Môn: `{"code":"PRM393","name":"Flutter Mobile","department_id":"507f1f77bcf86cd799439011"}`.

Phòng: `{"name":"BE-303","capacity":30}`.

Học kỳ:
```json
{"term":"SPRING","year":2027}
```
Server tự cấp code/name/start_at/end_at/academic_year. Không nhận ngày tự do. SPRING tháng 1–3, nghỉ tháng 4; SUMMER tháng 5–7, nghỉ tháng 8; FALL tháng 9–11, nghỉ tháng 12. Năm học bắt đầu bằng FALL rồi đến SPRING/SUMMER năm sau. end_at là mốc đầu tháng nghỉ, không bao gồm thời điểm này. Dùng múi giờ Việt Nam UTC+7.

Ngành và môn:
```json
{"code":"SE","name":"Kỹ thuật phần mềm","department_id":"507f1f77bcf86cd799439011","course_ids":["507f1f77bcf86cd799439013"]}
```
Cập nhật chương trình: `{"version":0,"course_ids":["507f1f77bcf86cd799439013"]}`. Một môn có thể nằm trong nhiều ngành để thể hiện môn chung. Gán ngành ban đầu: `{"version":0,"major_id":"507f1f77bcf86cd799439012"}`; không dùng endpoint này để đổi ngành đã có.

## Lớp, đăng ký, lịch và điểm danh

| Method | Đường dẫn | Quyền / hành vi |
|---|---|---|
| GET | /sections | STUDENT lớp đã đăng ký; LECTURER lớp phụ trách; STAFF tất cả |
| GET | /sections/available?course_id=...&semester_id=... | STUDENT chỉ môn ngành hiện tại; STAFF tất cả; có enrolled/remaining |
| POST | /sections | STAFF, lớp cố định 30 chỗ |
| PATCH | /sections/:id/status | STAFF mở/đóng đăng ký |
| GET | /sections/:id/sessions | STUDENT xem lịch lớp trước đăng ký, không nhận danh sách điểm danh; LECTURER/STAFF đúng phạm vi |
| GET | /sections/:id/enrollments | Theo phạm vi; STUDENT chỉ dòng bản thân |
| POST | /sections/:id/enrollments | STUDENT tự đăng ký; STAFF đăng ký thay |
| POST | /sections/:id/enrollments/:studentId/withdraw | STUDENT tự rút; STAFF rút thay |
| GET | /me/enrollments | STUDENT xem đăng ký hiện tại và đã rút |
| GET | /schedule?from=...&to=... | STUDENT/LECTURER/STAFF, đúng phạm vi, tối đa 93 ngày |
| POST | /sessions | STAFF xếp buổi theo ngày/slot |
| PATCH | /sessions/:id/schedule | STAFF đổi lịch trực tiếp |
| PATCH | /sessions/:id/status | STAFF đặt COMPLETED/CANCELLED |
| GET | /sessions/:id/history | LECTURER phụ trách / STAFF |
| GET | /sessions/:id/attendance | STUDENT bản thân / LECTURER phụ trách / STAFF |
| PUT | /sessions/:id/attendance | LECTURER phụ trách; đủ danh sách của buổi |
| GET | /sessions/:id/attendance-history | LECTURER phụ trách / STAFF |

HEAD không được đọc lịch, roster, đơn hoặc lịch sử điểm danh cá nhân.

Tạo lớp:
```json
{"code":"SE20B-PRM393","course_id":"507f1f77bcf86cd799439013","semester_id":"507f1f77bcf86cd799439014","lecturer_id":"507f1f77bcf86cd799439015"}
```
Không gửi capacity; server cố định 30. Mã lớp được dùng lại ở kỳ khác. Mở/đóng đăng ký: `{"version":0,"status":"CLOSED"}` hoặc OPEN.

Tạo buổi:
```json
{"section_id":"507f1f77bcf86cd799439016","room_id":"507f1f77bcf86cd799439017","session_date":"2027-01-15","slot_id":1}
```
4 slot: 07:30–09:50, 10:00–12:20, 12:50–15:10, 15:20–17:40. Server tự tính Date UTC, kiểm tra buổi nằm trong kỳ, phòng tối thiểu 30 chỗ và trùng phòng/giảng viên/lớp/sinh viên. Không nhận giờ tự do.

Sinh viên đăng ký body `{}`; STAFF đăng ký thay `{"student_id":"507f1f77bcf86cd799439018"}`. Cần có ngành hiện tại, môn nằm trong chương trình ngành và lớp đã có lịch tương lai. Chặn lớp đầy, trùng môn trong cùng kỳ, trùng lịch. Tranh chỗ thứ 30 chỉ một yêu cầu thành công. Rút lớp gửi `{"version":0}`; version lấy từ list đăng ký.

Điểm danh:
```json
{"version":0,"rows":[{"student_id":"507f1f77bcf86cd799439018","status":"ABSENT"}]}
```
Status PRESENT/ABSENT/LATE/EXCUSED. Chưa ghi nhận hiển thị NOT_RECORDED. Giảng viên gửi đủ danh sách tại thời điểm buổi bắt đầu; rút/đăng ký lại không làm mất điểm danh quá khứ. Sửa điểm danh giữ before/after trong audit.

STAFF đổi lịch trực tiếp:
```json
{"version":0,"room_id":"507f1f77bcf86cd799439017","session_date":"2027-01-15","slot_id":2,"reason":"Điều chỉnh lịch"}
```
Đặt trạng thái buổi: `{"version":0,"status":"CANCELLED","reason":"Nghỉ học"}` hoặc COMPLETED sau giờ kết thúc. Chỉ hủy buổi chưa bắt đầu, chưa điểm danh; slot hủy được sử dụng lại.

## Đơn nghỉ và đổi lịch/phòng

Danh sách đơn trả `{page, total, has_more, items}` với 50 đơn/trang, mới nhất trước. Mỗi đơn giữ các trường gốc và bổ sung `requester_name`, `requester_code`, `reviewer_name`, `section_code`, `course`, `session_date`, `slot_id`, `room_name`, `proposed_room_name`. `slot_id` của đơn nghỉ là ca tại thời điểm xin nghỉ. Không trả dữ liệu điểm danh hoặc thông tin đăng nhập trong danh sách này. Giảng viên chỉ đọc đơn nghỉ thuộc lớp mình và đơn đổi lịch do mình gửi.

Mỗi buổi chỉ có một yêu cầu đổi lịch/phòng `PENDING`; gửi trùng trả 409. Yêu cầu phải thay đổi ít nhất ngày, ca hoặc phòng. Chỉ đổi phòng thì giữ nguyên `proposed_date` và `proposed_slot_id`. Backend kiểm tra xung đột cả khi gửi và lúc cán bộ duyệt; gửi đơn chưa làm thay đổi lịch.

| Method | Đường dẫn | Quyền |
|---|---|---|
| POST | /leave-requests | STUDENT gửi nghỉ |
| GET | /leave-requests?status=PENDING&page=1 | STUDENT đơn của mình; LECTURER lớp phụ trách; STAFF |
| PATCH | /leave-requests/:id/decision | LECTURER phụ trách |
| POST | /change-requests | LECTURER phụ trách |
| GET | /change-requests?status=PENDING&page=1 | LECTURER đơn của mình; STAFF |
| PATCH | /change-requests/:id/decision | STAFF |

Gửi nghỉ: `{"session_id":"507f1f77bcf86cd799439019","reason":"Khám bệnh"}`. Server chụp ngày/slot hiện tại. Duyệt/từ chối: `{"version":0,"decision":"APPROVED","note":"Đồng ý"}` hoặc REJECTED.

Gửi đổi lịch:
```json
{"session_id":"507f1f77bcf86cd799439019","reason":"Phòng bảo trì","proposed_room_id":"507f1f77bcf86cd799439017","proposed_date":"2027-01-15","proposed_slot_id":2}
```
Một buổi chỉ có một yêu cầu đổi PENDING. STAFF duyệt mới cập nhật lịch, kiểm tra lại xung đột. Chỉ đổi phòng giữ đơn nghỉ; đổi ngày/slot làm các đơn nghỉ PENDING/APPROVED thành INVALIDATED. Sinh viên phải gửi đơn mới cho slot mới. Không ghi lại PRESENT khi duyệt nghỉ; GET attendance trả `note:"Nghỉ có phép"` bên cạnh trạng thái.

## Chuyển ngành

| Method | Đường dẫn | Quyền |
|---|---|---|
| POST | /major-transfer-requests | STUDENT |
| GET | /major-transfer-requests?status=PENDING&page=1 | STUDENT đơn của mình; STAFF tất cả |
| PATCH | /major-transfer-requests/:id/decision | STAFF |
| POST | /major-transfer-requests/:id/cancel | STUDENT chủ đơn, chỉ PENDING |

Gửi: `{"to_major_id":"507f1f77bcf86cd799439020","reason":"Muốn đổi ngành học"}`. Không cho gửi effective_at hoặc effective_semester_id. Server lấy kỳ kế tiếp sau thời điểm gửi. Ví dụ gửi trong Fall 2026 → hiệu lực đầu Spring 2027 (01/01/2027 giờ Việt Nam).

Duyệt: `{"version":0,"decision":"APPROVED","note":"Đồng ý chuyển kỳ sau"}`. Một sinh viên chỉ có một đơn PENDING hoặc APPROVED chưa áp dụng. Duyệt trước ngày hiệu lực; nếu đơn quá hạn chưa duyệt, sinh viên rút đơn và gửi mới. Rút đơn: `{"version":0}`.

Đến đầu kỳ, job chạy mỗi phút và kiểm tra đồng bộ lúc đăng nhập/xác thực sẽ áp dụng đơn đã duyệt. Đổi major_id/department_id, rút đăng ký môn thuộc ngành cũ nhưng không thuộc ngành mới ở kỳ hiệu lực trở đi; môn chung được giữ. Đăng ký và điểm danh các kỳ trước vẫn giữ nguyên. Trước ngày hiệu lực đăng ký theo ngành hiện tại; sau ngày hiệu lực theo ngành mới. applied_at thể hiện đã áp dụng; lệnh áp dụng chạy lại không tạo thay đổi trùng.

## Thông báo học vụ

| Method | Đường dẫn | Quyền |
|---|---|---|
| GET | /notices?page=1 | STUDENT thông báo hợp lệ đúng đối tượng; STAFF tất cả |
| GET | /notices/:id | STUDENT đúng đối tượng; STAFF |
| POST | /notices | STAFF tạo DRAFT |
| PATCH | /notices/:id | STAFF sửa DRAFT, gửi đủ nội dung/audience |
| POST | /notices/:id/publish | STAFF |
| POST | /notices/:id/archive | STAFF |
| POST | /notices/:id/read | STUDENT, idempotent |

Tạo nháp:
```json
{"title":"Lịch đăng ký môn","content":"Nội dung thông báo học vụ","audience":"ALL_STUDENTS"}
```
DEPARTMENT cần department_ids; MAJOR cần major_ids. Chỉ một kiểu audience; không trộn các danh sách. Có thể gửi expires_at ISO có offset hoặc null. Nội dung là văn bản thuần, tối đa 5000 ký tự.

Phát hành/lưu trữ: `{"version":0}`. Chỉ PUBLISHED chưa hết hạn và đúng ngành/bộ môn hiện tại mới hiển thị cho sinh viên. DRAFT/ARCHIVED/ngoài đối tượng trả 404 khi truy cập chi tiết. Không sửa nội dung đã phát hành; lưu trữ rồi tạo bản mới. /read giữ thời điểm đọc đầu tiên, không nhân đôi. Đây là thông báo trong ứng dụng, chưa gửi push/email.

## Báo cáo

| Method | Đường dẫn | Quyền |
|---|---|---|
| GET | /department/summary?semester_id=... | HEAD tổng quan bộ môn |
| GET | /reports/attendance?semester_id=...&course_id=...&lecturer_id=...&section_id=...&group_by=SECTION | HEAD |
| GET | /reports/requests?semester_id=... | HEAD |

group_by nhận SECTION/COURSE/LECTURER. Báo cáo gồm số lớp/buổi, buổi hủy/hoàn tất/đã điểm danh, số lượt PRESENT/LATE/ABSENT/EXCUSED, số đăng ký ACTIVE và presence_rate. presence_rate = (PRESENT + LATE) / tổng lượt đã ghi × 100; không có dữ liệu trả null, không suy diễn thành điểm chuyên cần. Báo cáo đơn đếm status/count theo loại; chuyển ngành được giới hạn bộ môn xuất phát và kỳ hiệu lực. Chặn bộ lọc ngoài bộ môn tài khoản. Không trả hồ sơ liên hệ hoặc lý do đơn của sinh viên cho HEAD.

## Giới hạn và lỗi

List đơn nghỉ/đổi lịch 50 dòng/trang; thông báo/chuyển ngành 20 dòng/trang. Danh mục/lớp tối đa 200, lịch tối đa 1000, lịch sử tối đa 200. Báo cáo tổng hợp trên DB theo phạm vi bộ môn.

400 input/ID/JSON sai; 401 sai đăng nhập hoặc phiên hết hạn/thu hồi; 403 sai quyền; 404 không có dữ liệu trong phạm vi; 409 trùng/version cũ/sai trạng thái/lớp đầy; 413 JSON >64 KiB; 429 vượt giới hạn; 500 lỗi nội bộ. Dạng lỗi `{"message":"..."}`, validation có issues. Không trả stack trace, password_hash hoặc token_hash.
