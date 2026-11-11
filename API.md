# MyFAP API — phạm vi các màn đã chốt

Base URL: `http://localhost:3000/api`. Android Emulator: `http://10.0.2.2:3000/api`. Ngoài health/login, gửi `Authorization: Bearer <accessToken>`. ID là ObjectId 24 ký tự hex, response dùng `id`. Body không nhận trường ngoài schema.

## Mô hình và quyền

- Course là môn; Semester là kỳ cụ thể; Section là lớp học phần của một môn trong một kỳ, tối đa 30 sinh viên. Không phải lớp hành chính gắn cố định với sinh viên.
- ClassSession là một buổi thuộc Section, gồm ngày, slot, phòng và `lecturer_id` có thể null. Giảng viên được xác định trên từng buổi. `Section.lecturer_id` cũ chỉ còn trong dữ liệu lưu trữ, không dùng cấp quyền/phân công.
- Enrollment và EnrollmentPeriod lưu việc sinh viên tham gia/rút lớp theo thời điểm; không có lớp cố định trên User. Roster lấy theo khoảng đăng ký phủ giờ bắt đầu buổi. Không xóa điểm danh/lịch sử khi rút hoặc đăng ký lại.
- HEAD quản lý môn, lớp, phân công và báo cáo trong bộ môn của mình. LECTURER thao tác trên buổi mình phụ trách. STUDENT chỉ thao tác dữ liệu bản thân. STAFF gửi thông báo và duyệt đổi lịch/phòng.
- `version` lấy từ GET gần nhất, bắt đầu 0; version cũ trả 409. Các thao tác học vụ dùng transaction và audit. Không sửa/xóa buổi quá khứ khi phân công lại.

## Đăng nhập và hồ sơ

| Method | Endpoint | Quyền |
|---|---|---|
| GET | `/health` | Công khai, kiểm tra MongoDB |
| POST | `/auth/login` | Công khai, có rate limit |
| POST | `/auth/logout` | Đã đăng nhập; thu hồi phiên, trả 204 |
| GET | `/profile` | Mọi role, chỉ xem bản thân |

Login body: `{"email":"lecturer@myfap.local","password":"Demo@12345678"}`. Response: `{accessToken,expiresAt,user}`; user có role để chọn màn, không có password hash. Phiên mặc định 8 giờ.

Profile trả `{id,user_code,name,email,role,major}`; major chỉ có cho sinh viên, gồm id/code/name hoặc null. Không trả thông tin liên hệ, bộ môn, ảnh hoặc đơn chuyển ngành. Không có API cập nhật hồ sơ/đổi mật khẩu. Avatar do frontend lấy chữ từ tên; không có upload ảnh.

## Danh mục hỗ trợ và quản lý môn

| Method | Endpoint | Quyền / mục đích |
|---|---|---|
| GET | `/courses` | Đã đăng nhập; HEAD chỉ thấy môn của bộ môn, có `major_ids` để điền form |
| GET | `/semesters` | Đã đăng nhập; các kỳ chuẩn, không trả kỳ legacy |
| GET | `/rooms` | Đã đăng nhập; chọn phòng trong form |
| GET | `/time-slots` | Đã đăng nhập; 4 khung giờ cố định |
| GET | `/majors` | HEAD; ngành hoạt động trong bộ môn, chỉ đọc để gắn môn vào chương trình |
| POST | `/courses` | HEAD; tạo môn trong bộ môn của mình |
| PATCH | `/courses/:id` | HEAD; sửa/ngừng sử dụng môn thuộc bộ môn |

Tạo môn:
```json
{"code":"PRM393","name":"Flutter Mobile","major_ids":["507f1f77bcf86cd799439011"]}
```
`major_ids` mặc định []; chỉ chọn ngành hoạt động trong bộ môn. Môn chưa thuộc chương trình nào vẫn được tạo, nhưng sinh viên chưa đăng ký được môn đó. Không nhận department_id từ client.

Cập nhật môn:
```json
{"version":0,"name":"Lập trình di động","active":true,"major_ids":["507f1f77bcf86cd799439011"]}
```
Các trường code/name/active/major_ids đều tùy chọn nhưng phải có ít nhất một trường cập nhật. Nếu không gửi major_ids thì giữ chương trình hiện tại; [] gỡ môn khỏi các ngành của bộ môn. Không sửa chương trình của bộ môn khác. Ngừng môn bằng active=false; giữ các lớp/buổi/đăng ký cũ, chỉ chặn tạo lớp và đăng ký mới. Không có DELETE môn.

Kỳ: Fall tháng 9–11, Spring 1–3, Summer 5–7; nghỉ tháng 12/4/8. Mốc theo UTC+7, end_at là đầu tháng nghỉ (exclusive). Danh mục kỳ/phòng/bộ môn/tài khoản được chuẩn bị bằng seed/công cụ thiết lập, không có REST CRUD riêng.

## Lớp và phân công giảng dạy

| Method | Endpoint | Quyền |
|---|---|---|
| GET | `/lecturers` | HEAD; giảng viên hoạt động cùng bộ môn, chỉ id/name/user_code/department_id |
| GET | `/sections?semester_id=...&course_id=...` | HEAD lớp trong bộ môn; LECTURER lớp có buổi được giao; STUDENT lớp đã đăng ký, gồm lịch sử |
| POST | `/sections` | HEAD; tạo lớp chưa phân công, mặc định CLOSED |
| PATCH | `/sections/:id/status` | HEAD trong bộ môn; mở/đóng đăng ký |
| GET | `/sections/:id/sessions` | HEAD toàn bộ buổi trong lớp cùng bộ môn; LECTURER chỉ buổi được giao; STUDENT xem lịch lớp trước đăng ký |
| PUT | `/sections/:id/assignments` | HEAD trong bộ môn; phân công/đổi/hủy phân công các buổi tương lai |

Tạo lớp:
```json
{"code":"SE20A-PRM393","course_id":"507f1f77bcf86cd799439012","semester_id":"507f1f77bcf86cd799439013"}
```
Không nhận lecturer_id/capacity: lớp chưa có giảng viên, capacity=30. DTO lớp có `assignment_basis:"SESSION"`, không trả trường lecturer_id cũ như một phân công hiện tại.

Mở đăng ký: `{"version":0,"status":"OPEN"}` hoặc CLOSED. Chỉ mở khi môn hoạt động và có buổi tương lai đúng slot. Buổi có phòng/lịch hợp lệ vẫn có thể mở đăng ký khi giảng viên chưa phân công. Tạo buổi ban đầu là công việc thiết lập, không thêm màn/API xếp lịch ngoài phạm vi.

Phân công:
```json
{
  "reason":"Phân công giảng dạy tuần tới",
  "assignments":[
    {"session_id":"507f1f77bcf86cd799439014","lecturer_id":"507f1f77bcf86cd799439015","version":0},
    {"session_id":"507f1f77bcf86cd799439016","lecturer_id":null,"version":2}
  ]
}
```
Tối đa 200 buổi, không lặp ID; null là hủy phân công. Mỗi buổi phải thuộc lớp, chưa bắt đầu, SCHEDULED và chưa điểm danh. Giảng viên phải hoạt động, cùng bộ môn. Kiểm tra trùng lớp/phòng/giảng viên/sinh viên; lỗi một buổi hoàn tác toàn bộ đợt. Các lần thay đổi có audit và snapshot giảng viên cũ/mới.

Đổi người phụ trách hủy các đơn đổi lịch/phòng PENDING của buổi để tránh đề xuất từ người cũ; đơn nghỉ giữ nguyên nếu ngày/slot không đổi. Giảng viên cũ vẫn đọc yêu cầu mình đã gửi và các buổi quá khứ từng phụ trách; không được điểm danh/duyệt nghỉ trên buổi tương lai đã giao cho người khác.

## Đăng ký môn và lịch cá nhân

| Method | Endpoint | Quyền |
|---|---|---|
| GET | `/sections/available?semester_id=...&course_id=...` | STUDENT; lớp mở có lịch tương lai, môn thuộc ngành hiện tại, có enrolled/remaining |
| GET | `/me/enrollments` | STUDENT; đăng ký bản thân, gồm ACTIVE/WITHDRAWN và version |
| POST | `/sections/:id/enrollments` | STUDENT; body `{}` |
| POST | `/sections/:id/enrollments/:studentId/withdraw` | STUDENT bản thân; body `{"version":0}` |
| GET | `/schedule?from=...&to=...` | STUDENT/LECTURER; tối đa 93 ngày, đúng phạm vi thời điểm |

Đăng ký kiểm tra ngành/chương trình, môn hoạt động, lịch đã có, chỗ còn, trùng môn cùng kỳ và trùng lịch. Một môn tối đa một đăng ký ACTIVE mỗi sinh viên/kỳ. Lớp đầy trả 409. Rút không xóa dữ liệu cũ; đăng ký lại mở EnrollmentPeriod mới. Không có API cán bộ đăng ký/rút thay hoặc đơn chuyển lớp sinh viên trong MVP này.

Ví dụ lịch: `/schedule?from=2026-11-08T17:00:00Z&to=2026-11-15T17:00:00Z`. Giảng viên lọc trực tiếp lecturer_id trên buổi; sinh viên lọc khoảng đăng ký tại giờ buổi học. Response giữ các trường id/section_id/section_code/course/course_code/semester_id/session_date/slot_id/start_at/end_at/room_id/room_name/lecturer_id/status/version/attendance_saved; không chứa roster/điểm danh của người khác. lecturer_id có thể null.

4 slot: 1=07:30–09:50, 2=10:00–12:20, 3=12:50–15:10, 4=15:20–17:40. Thời gian lưu UTC; ngày/slot theo Việt Nam.

## Điểm danh

| Method | Endpoint | Quyền |
|---|---|---|
| GET | `/sessions/:id/attendance` | LECTURER phụ trách đúng buổi |
| PUT | `/sessions/:id/attendance` | LECTURER phụ trách, buổi đã bắt đầu và chưa hủy |

GET trả `{version,saved,session_status,rows:[{student_id,user_code,name,status,approved_leave_id,note}]}`. Chưa ghi nhận là NOT_RECORDED. Đơn nghỉ duyệt đúng ngày/slot thêm note "Nghỉ có phép", frontend hiện "Đã duyệt đơn nghỉ", không tự đổi sang PRESENT.

PUT phải gửi đủ roster, không lặp sinh viên:
```json
{"version":1,"rows":[{"student_id":"507f1f77bcf86cd799439017","status":"ABSENT"}]}
```
Điểm danh mới chỉ PRESENT/ABSENT. LATE/EXCUSED đã tồn tại có thể đọc và gửi lại nguyên trạng; không được tạo mới/chuyển sang hai giá trị này. Thành công trả `{version}`; đọc lại roster trước lần sửa tiếp. Lịch sử điểm danh vẫn lưu audit nhưng không có REST endpoint riêng.

## Đơn nghỉ và yêu cầu đổi lịch/phòng

| Method | Endpoint | Quyền |
|---|---|---|
| POST | `/leave-requests` | STUDENT xin nghỉ buổi tương lai thuộc đăng ký của mình |
| GET | `/leave-requests?status=PENDING&page=1` | STUDENT đơn mình; LECTURER đơn của buổi đang phụ trách |
| PATCH | `/leave-requests/:id/decision` | LECTURER phụ trách buổi |
| POST | `/change-requests` | LECTURER phụ trách buổi tương lai |
| GET | `/change-requests?status=PENDING&page=1` | LECTURER chỉ đơn mình gửi; STAFF các đơn để duyệt |
| PATCH | `/change-requests/:id/decision` | STAFF |

Xin nghỉ: `{"session_id":"507f1f77bcf86cd799439014","reason":"Khám bệnh"}`.

Đổi lịch/phòng:
```json
{"session_id":"507f1f77bcf86cd799439014","reason":"Phòng cần bảo trì","proposed_room_id":"507f1f77bcf86cd799439018","proposed_date":"2026-11-20","proposed_slot_id":2}
```
Đổi phòng giữ ngày/slot; đổi lịch có thể giữ phòng. Chỉ có một đề xuất PENDING/buổi. Cán bộ duyệt mới cập nhật lịch, kiểm tra lại version và xung đột. Đổi ngày/slot vô hiệu đơn nghỉ PENDING/APPROVED cũ; chỉ đổi phòng giữ đơn.

Duyệt/từ chối cả hai loại: `{"version":0,"decision":"APPROVED","note":"Đã kiểm tra"}` hoặc REJECTED. note bắt buộc, tối đa 1000 ký tự. Danh sách trả `{page,items}`, 50 dòng/trang; có requester(name/user_code), lesson(lớp/môn/ngày/slot/phòng), tên phòng cũ/đề xuất và phản hồi. Không có thông tin liên hệ/password hash của sinh viên.

## Thông báo

| Method | Endpoint | Quyền |
|---|---|---|
| POST | `/notices` | STAFF tạo nháp |
| POST | `/notices/:id/publish` | STAFF phát hành; body `{"version":0}` |
| GET | `/notices?page=1&status=PUBLISHED` | STAFF lọc nháp/đã phát hành/lưu trữ; STUDENT chỉ bản đã phát hành, chưa hết hạn, đúng đối tượng |
| GET | `/notices/:id` | STUDENT/STAFF, đúng phạm vi |

Body tạo: `{"title":"Đăng ký môn","content":"Kiểm tra lịch đăng ký.","audience":"ALL_STUDENTS"}`. title tối đa 160, content 5000. audience có ALL_STUDENTS / DEPARTMENT / MAJOR; hai loại sau phải gửi department_ids hoặc major_ids tương ứng. expires_at ISO datetime hoặc null. Danh sách 20 dòng/trang.

Không có API sửa/lưu trữ/đánh dấu đọc thông báo vì ngoài các màn đã chốt. Các bản ARCHIVED và lịch sử đọc cũ vẫn được giữ trong DB. Không tích hợp push/email.

## Báo cáo HEAD

| Method | Endpoint | Tham số |
|---|---|---|
| GET | `/department/summary` | semester_id tùy chọn |
| GET | `/reports/attendance` | semester_id/course_id/lecturer_id/section_id tùy chọn; group_by=SECTION/COURSE/LECTURER |

Chỉ phạm vi bộ môn của HEAD; bộ lọc ngoài bộ môn trả 403. Thống kê theo giảng viên dùng người phụ trách từng buổi, không dựa vào trường cũ trên lớp. Nhóm chưa phân công có id=null. presence_rate=(PRESENT+LATE)/số dòng đã điểm danh; không có dữ liệu trả null. Buổi hủy không tính vào tỷ lệ.

## Lỗi và API đã bỏ

401: chưa đăng nhập/token hết hạn. 403: sai role/phạm vi. 404: dữ liệu không tồn tại hoặc API đã bỏ. 400: đầu vào sai. 409: version cũ, trùng lịch, đủ chỗ hoặc trạng thái không còn hợp lệ. Lỗi trả `{message}`; Zod có thêm issues. Không gửi selector MongoDB trong body/query.

Đã bỏ `/auth/me`, PATCH profile/password, CRUD ngành và chuyển ngành, GET departments, POST users/departments/semesters/rooms, POST sessions, PATCH lịch/trạng thái buổi trực tiếp, GET lịch sử lịch/điểm danh, GET roster theo lớp, GET reports/requests và các API sửa/archive/read thông báo. STAFF không còn quyền tạo môn/lớp hoặc đăng ký thay sinh viên. Không thay bằng route tắt xác thực cho test.

## Chuyển dữ liệu và thiết lập

Backup trước khi cập nhật. Không chạy seed toàn bộ lên DB đang có dữ liệu.
```powershell
cd D:\Study\Project\myfap_clone\backend
npm run scope:preview
npm run scope:migrate
```
Migration thay đúng index giảng viên cũ bằng partial unique index chỉ áp dụng khi lecturer_id là ObjectId. Không rewrite/xóa document hoặc syncIndexes hàng loạt. Startup db:init cũng đảm bảo index này. Giữ nguyên Section.lecturer_id cũ, ClassSession.lecturer_id cũ, enrollment periods, audit, đơn và điểm danh. Collection chuyển ngành còn lưu trữ nhưng không có job/xác thực tự áp dụng.

Buổi ban đầu được seed/import hoặc tạo bằng công cụ vận hành sau khi HEAD tạo lớp:
```powershell
npm run setup:session -- --head=HEAD_ID --section=SECTION_ID --room=ROOM_ID --date=2026-11-20 --slot=1
```
Thay các ID bằng ObjectId thật. Lệnh kiểm tra HEAD cùng bộ môn, kỳ/slot/phòng/trùng lịch và tạo buổi chưa phân công; sau đó HEAD dùng PUT assignments, PATCH section/status trên màn phân công. Công cụ CLI không mở thêm REST endpoint. Các danh mục ban đầu vẫn dùng seed/import hiện có.

Kiểm thử: npm test; test:workflow, test:affairs, test:import với MONGODB_URI riêng, DB trống có hậu tố `_test` theo README. Không chạy test trên myfap.

## Tích hợp HEAD với main

Giữ các màn sinh viên, giảng viên và hồ sơ chỉ đọc từ main. HEAD có bốn màn: Báo cáo bộ môn, Quản lý môn học, Phân công theo buổi và Gửi đơn chuyển phòng; không có màn theo dõi chuyên cần từng sinh viên.

HEAD dùng `GET /head/options`, `GET /head/courses?search=&page=1`, `GET /head/sections?semester_id=&course_id=&page=1` làm dữ liệu cho màn hình. Hai danh sách trả `{page,total,has_more,items}` với 50 dòng/trang. Options chỉ có môn, ngành, giảng viên hoạt động cùng bộ môn và học kỳ chuẩn.

`POST /head/courses` và `PATCH /head/courses/:id` là alias của nghiệp vụ `/courses` trên main: cùng validator, transaction, version, active và major_ids. Client không chọn bộ môn. Không duy trì hai cách cập nhật chương trình môn khác nhau.

Phân công dùng `GET /sections/:id/sessions` và `PUT /sections/:id/assignments` của main. Body gồm `assignments:[{session_id,lecturer_id,version}]` và `reason`; lecturer_id có thể null để bỏ phân công. Chỉ buổi tương lai chưa điểm danh, kiểm tra trùng giờ và rollback nguyên đợt nếu một dòng lỗi. Khi đổi giảng viên, hủy đơn đổi lịch/phòng PENDING của buổi, giữ đơn nghỉ. Không dùng API phân công giảng viên theo Section cũ.

HEAD được xem `/schedule` trong bộ môn và gửi `/change-requests` nhưng không đổi ngày/ca. Danh sách đơn HEAD chỉ gồm đơn tự gửi cho buổi cùng bộ môn. STAFF vẫn duyệt/từ chối. Response đơn giữ cấu trúc requester/lesson của main, bổ sung total/has_more cho phân trang HEAD.

`GET /reports/requests?semester_id=...` bổ sung thống kê đơn nghỉ và đơn đổi lịch/phòng trong bộ môn cho HEAD; role khác trả 403. Không khôi phục API chuyển ngành, sửa hồ sơ, xếp lịch hoặc các API ngoài scope đã bỏ trên main.
