# MyFAP API — phạm vi các màn đã chốt

Base URL: `http://localhost:3000/api`. Android Emulator: `http://10.0.2.2:3000/api`. Ngoài health/login, gửi `Authorization: Bearer <accessToken>`. ID là ObjectId 24 ký tự hex, response dùng `id`. Body không nhận trường ngoài schema.

## Mô hình và quyền

- Course là môn; Semester là kỳ cụ thể; Section là lớp học phần của một môn trong một kỳ, tối đa 30 sinh viên. Không phải lớp hành chính gắn cố định với sinh viên.
- ClassSession là một buổi thuộc Section, gồm ngày, slot, phòng và `lecturer_id` có thể null. Giảng viên được xác định trên từng buổi. `Section.lecturer_id` cũ chỉ còn trong dữ liệu lưu trữ, không dùng cấp quyền/phân công.
- ClassMembership lưu các khoảng thời gian sinh viên thuộc lớp; không có lớp cố định trên User. Roster lấy theo khoảng thuộc lớp phủ giờ bắt đầu buổi. Không xóa điểm danh/lịch sử khi sinh viên thay đổi lớp.
- HEAD quản lý môn, lớp, phân công và báo cáo trong bộ môn của mình. LECTURER thao tác trên buổi mình phụ trách. STUDENT chỉ thao tác dữ liệu bản thân. STAFF gửi thông báo, duyệt đổi lịch/phòng và duyệt chuyển ngành.
- `version` lấy từ GET gần nhất, bắt đầu 0; version cũ trả 409. Các thao tác học vụ dùng transaction và audit. Không sửa/xóa buổi quá khứ khi phân công lại.

## Đăng nhập và hồ sơ

| Method | Endpoint       | Quyền                                |
| ------ | -------------- | ------------------------------------ |
| GET    | `/health`      | Công khai, kiểm tra MongoDB          |
| POST   | `/auth/login`  | Công khai, có rate limit             |
| POST   | `/auth/logout` | Đã đăng nhập; thu hồi phiên, trả 204 |
| GET    | `/profile`     | Mọi role, chỉ xem bản thân           |

Login body: `{"email":"lecturer@myfap.local","password":"Demo@12345678"}`. Response: `{accessToken,expiresAt,user}`; user có role để chọn màn, không có password hash. Phiên mặc định 8 giờ.

Profile trả `{id,user_code,name,email,role,major}`; major chỉ có cho sinh viên, gồm id/code/name hoặc null. Không trả thông tin liên hệ, bộ môn hoặc ảnh. Không có API cập nhật hồ sơ/đổi mật khẩu. Avatar do frontend lấy chữ đầu tiên từ tên; không có upload ảnh.

## Danh mục hỗ trợ và quản lý môn

| Method | Endpoint       | Quyền / mục đích                                                        |
| ------ | -------------- | ----------------------------------------------------------------------- |
| GET    | `/courses`     | Đã đăng nhập; HEAD chỉ thấy môn của bộ môn, có `major_ids` để điền form |
| GET    | `/semesters`   | Đã đăng nhập; các kỳ chuẩn, không trả kỳ legacy                         |
| GET    | `/rooms`       | Đã đăng nhập; chọn phòng trong form                                     |
| GET    | `/time-slots`  | Đã đăng nhập; 4 khung giờ cố định                                       |
| GET    | `/majors`      | HEAD; ngành hoạt động trong bộ môn, chỉ đọc để gắn môn vào chương trình |
| POST   | `/courses`     | HEAD; tạo môn trong bộ môn của mình                                     |
| PATCH  | `/courses/:id` | HEAD; sửa/ngừng sử dụng môn thuộc bộ môn                                |

Tạo môn:

```json
{
  "code": "PRM393",
  "name": "Flutter Mobile",
  "major_ids": ["507f1f77bcf86cd799439011"]
}
```

`major_ids` mặc định []; chỉ chọn ngành hoạt động trong bộ môn. Môn chưa thuộc chương trình nào vẫn được tạo, nhưng chưa đưa vào lịch học của ngành đó. Không nhận department_id từ client.

Cập nhật môn:

```json
{
  "version": 0,
  "name": "Lập trình di động",
  "active": true,
  "major_ids": ["507f1f77bcf86cd799439011"]
}
```

Các trường code/name/active/major_ids đều tùy chọn nhưng phải có ít nhất một trường cập nhật. Nếu không gửi major_ids thì giữ chương trình hiện tại; [] gỡ môn khỏi các ngành của bộ môn. Không sửa chương trình của bộ môn khác. Ngừng môn bằng active=false; giữ các lớp/buổi cũ, chặn tạo lớp mới. Không có DELETE môn.

Kỳ: Fall tháng 9–11, Spring 1–3, Summer 5–7; nghỉ tháng 12/4/8. Mốc theo UTC+7, end_at là đầu tháng nghỉ (exclusive). Danh mục kỳ/phòng/bộ môn/tài khoản được chuẩn bị bằng seed/công cụ thiết lập, không có REST CRUD riêng.

## Lớp và phân công giảng dạy

| Method | Endpoint                                  | Quyền                                                                                                    |
| ------ | ----------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| GET    | `/lecturers`                              | HEAD; giảng viên hoạt động cùng bộ môn, chỉ id/name/user_code/department_id                              |
| GET    | `/sections?semester_id=...&course_id=...` | HEAD lớp trong bộ môn; LECTURER lớp có buổi được giao; STUDENT lớp đang/đã thuộc, gồm lịch sử               |
| POST   | `/sections`                               | HEAD; tạo lớp chưa phân công, mặc định CLOSED                                                            |
| GET    | `/sections/:id/sessions`                  | HEAD toàn bộ buổi trong lớp cùng bộ môn; LECTURER chỉ buổi được giao; STUDENT xem lịch lớp của mình |
| PUT    | `/sections/:id/assignments`               | HEAD trong bộ môn; phân công/đổi/hủy phân công các buổi tương lai                                        |

Tạo lớp:

```json
{
  "code": "SE20A-PRM393",
  "course_id": "507f1f77bcf86cd799439012",
  "semester_id": "507f1f77bcf86cd799439013"
}
```

Không nhận lecturer_id/capacity: lớp chưa có giảng viên, capacity=30. DTO lớp có `assignment_basis:"SESSION"`, không trả trường lecturer_id cũ như một phân công hiện tại.

Danh sách sinh viên thuộc lớp do seed/import thiết lập. Tạo buổi ban đầu là công việc thiết lập, không thêm màn/API xếp lịch ngoài phạm vi.

Phân công:

```json
{
  "reason": "Phân công giảng dạy tuần tới",
  "assignments": [
    {
      "session_id": "507f1f77bcf86cd799439014",
      "lecturer_id": "507f1f77bcf86cd799439015",
      "version": 0
    },
    {
      "session_id": "507f1f77bcf86cd799439016",
      "lecturer_id": null,
      "version": 2
    }
  ]
}
```

Tối đa 200 buổi, không lặp ID; null là hủy phân công. Mỗi buổi phải thuộc lớp, chưa bắt đầu, SCHEDULED và chưa điểm danh. Giảng viên phải hoạt động, cùng bộ môn. Kiểm tra trùng lớp/phòng/giảng viên/sinh viên; lỗi một buổi hoàn tác toàn bộ đợt. Các lần thay đổi có audit và snapshot giảng viên cũ/mới.

Đổi người phụ trách hủy các đơn đổi lịch/phòng PENDING của buổi để tránh đề xuất từ người cũ; đơn nghỉ giữ nguyên nếu ngày/slot không đổi. Giảng viên cũ vẫn đọc yêu cầu mình đã gửi và các buổi quá khứ từng phụ trách; không được điểm danh/duyệt nghỉ trên buổi tương lai đã giao cho người khác.

## Lịch cá nhân

| Method | Endpoint                    | Quyền                                                    |
| ------ | --------------------------- | -------------------------------------------------------- |
| GET    | `/schedule?from=...&to=...` | STUDENT/LECTURER; tối đa 93 ngày, đúng phạm vi thời điểm |

Không còn chức năng tự tìm lớp mở đăng ký hoặc mở/đóng đăng ký lớp. Danh sách sinh viên thuộc lớp do seed/import thiết lập.

Ví dụ lịch: `/schedule?from=2026-11-08T17:00:00Z&to=2026-11-15T17:00:00Z`. Giảng viên lọc trực tiếp lecturer_id trên buổi; sinh viên lọc khoảng thuộc lớp tại giờ buổi học. Response giữ các trường id/section_id/section_code/course/course_code/semester_id/session_date/slot_id/start_at/end_at/room_id/room_name/lecturer_id/status/version/attendance_saved; không chứa roster/điểm danh của người khác. Sinh viên nhận thêm `my_attendance` và `approved_leave`: đơn nghỉ được duyệt đúng thời gian buổi học có thể hiển thị trước khi giảng viên điểm danh. lecturer_id có thể null.

4 slot: 1=07:30–09:50, 2=10:00–12:20, 3=12:50–15:10, 4=15:20–17:40. Thời gian lưu UTC; ngày/slot theo Việt Nam.

## Điểm danh

| Method | Endpoint                   | Quyền                                           |
| ------ | -------------------------- | ----------------------------------------------- |
| GET    | `/sessions/:id/attendance` | LECTURER phụ trách đúng buổi                    |
| PUT    | `/sessions/:id/attendance` | LECTURER phụ trách, buổi đã bắt đầu và chưa hủy |

GET trả `{version,saved,session_status,rows:[{student_id,user_code,name,status,approved_leave_id,note}]}`. Chưa ghi nhận là NOT_RECORDED. Đơn nghỉ duyệt đúng ngày/slot thêm note "Nghỉ có phép". Khi giảng viên chọn ABSENT và lưu, backend ghi EXCUSED; PRESENT vẫn là PRESENT.

PUT phải gửi đủ roster, không lặp sinh viên:

```json
{
  "version": 1,
  "rows": [{ "student_id": "507f1f77bcf86cd799439017", "status": "ABSENT" }]
}
```

Điểm danh đầu vào chỉ PRESENT/ABSENT. Backend tự chuyển ABSENT thành EXCUSED nếu có đơn nghỉ được duyệt đúng buổi; LATE/EXCUSED đã tồn tại có thể đọc và gửi lại nguyên trạng. Thành công trả `{version}`; đọc lại roster trước lần sửa tiếp. Lịch sử điểm danh vẫn lưu audit nhưng không có REST endpoint riêng.

## Đơn nghỉ và yêu cầu đổi lịch/phòng

| Method | Endpoint                                 | Quyền                                                  |
| ------ | ---------------------------------------- | ------------------------------------------------------ |
| POST   | `/leave-requests`                        | STUDENT xin nghỉ buổi tương lai thuộc lớp của mình |
| GET    | `/leave-requests?status=PENDING&page=1`  | STUDENT đơn mình; LECTURER đơn của buổi đang phụ trách |
| PATCH  | `/leave-requests/:id/decision`           | LECTURER phụ trách buổi                                |
| POST   | `/change-requests`                       | LECTURER phụ trách buổi tương lai                      |
| GET    | `/change-requests?status=PENDING&page=1` | LECTURER chỉ đơn mình gửi; STAFF các đơn để duyệt      |
| PATCH  | `/change-requests/:id/decision`          | STAFF                                                  |

Xin nghỉ: `{"session_id":"507f1f77bcf86cd799439014","reason":"Khám bệnh"}`.

Đơn nghỉ và đơn đổi lịch/phòng còn PENDING sẽ thành EXPIRED khi buổi học bắt đầu. Bộ quét chạy lúc khởi động API và mỗi phút; sau thời điểm bắt đầu, cả duyệt lẫn từ chối đều không còn hợp lệ. Có thể lọc `status=EXPIRED` trong hai danh sách.

Đổi lịch/phòng:

```json
{
  "session_id": "507f1f77bcf86cd799439014",
  "reason": "Phòng cần bảo trì",
  "proposed_room_id": "507f1f77bcf86cd799439018",
  "proposed_date": "2026-11-20",
  "proposed_slot_id": 2
}
```

Đổi phòng giữ ngày/slot; đổi lịch có thể giữ phòng. Chỉ có một đề xuất PENDING/buổi. Cán bộ duyệt mới cập nhật lịch, kiểm tra lại version và xung đột. Đổi ngày/slot vô hiệu đơn nghỉ PENDING/APPROVED cũ; chỉ đổi phòng giữ đơn.

Duyệt/từ chối cả hai loại: `{"version":0,"decision":"APPROVED","note":"Đã kiểm tra"}` hoặc REJECTED. note bắt buộc, tối đa 1000 ký tự. Danh sách trả `{page,items}`, 50 dòng/trang; có requester(name/user_code), lesson(lớp/môn/ngày/slot/phòng), tên phòng cũ/đề xuất và phản hồi. Không có thông tin liên hệ/password hash của sinh viên.

## Thông báo

| Method | Endpoint                           | Quyền                                                                                           |
| ------ | ---------------------------------- | ----------------------------------------------------------------------------------------------- |
| POST   | `/notices`                         | STAFF tạo nháp                                                                                  |
| POST   | `/notices/:id/publish`             | STAFF phát hành; body `{"version":0}`                                                           |
| GET    | `/notices?page=1&status=PUBLISHED` | STAFF lọc nháp/đã phát hành/lưu trữ; STUDENT chỉ bản đã phát hành, chưa hết hạn, đúng đối tượng |
| GET    | `/notices/:id`                     | STUDENT/STAFF, đúng phạm vi                                                                     |

| Method | Endpoint                                         | Quyền / mục đích                                                                                                        |
| ------ | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| GET    | `/major-transfer-options`                        | STUDENT; danh sách ngành đang hoạt động                                                                                 |
| POST   | `/major-transfer-requests`                       | STUDENT gửi đơn `{to_major_id,reason}`                                                                                  |
| GET    | `/major-transfer-requests?page=1&status=PENDING` | STUDENT chỉ xem đơn của mình; STAFF xem/lọc mọi đơn                                                                     |
| PATCH  | `/major-transfer-requests/:id/decision`          | STAFF duyệt/từ chối với `{version,decision,note}`; duyệt lên lịch chuyển ngành từ học kỳ tiếp theo, chưa đổi ngành ngay |

Body tạo: `{"title":"Lịch học kỳ mới","content":"Kiểm tra lịch học.","audience":"ALL_STUDENTS"}`. title tối đa 160, content 5000. audience có ALL_STUDENTS / DEPARTMENT / MAJOR; hai loại sau phải gửi department_ids hoặc major_ids tương ứng. expires_at ISO datetime hoặc null. Danh sách 20 dòng/trang.

Không có API sửa/lưu trữ/đánh dấu đọc thông báo vì ngoài các màn đã chốt. Các bản ARCHIVED và lịch sử đọc cũ vẫn được giữ trong DB. Không tích hợp push/email.

## Báo cáo HEAD

| Method | Endpoint              | Tham số                                                                                 |
| ------ | --------------------- | --------------------------------------------------------------------------------------- |
| GET    | `/department/summary` | semester_id tùy chọn                                                                    |
| GET    | `/reports/attendance` | semester_id/course_id/lecturer_id/section_id tùy chọn; group_by=SECTION/COURSE/LECTURER |

Chỉ phạm vi bộ môn của HEAD; bộ lọc ngoài bộ môn trả 403. Thống kê theo giảng viên dùng người phụ trách từng buổi, không dựa vào trường cũ trên lớp. Nhóm chưa phân công có id=null. presence_rate=(PRESENT+LATE)/số dòng đã điểm danh; không có dữ liệu trả null. Buổi hủy không tính vào tỷ lệ.

## Lỗi và API đã bỏ

401: chưa đăng nhập/token hết hạn. 403: sai role/phạm vi. 404: dữ liệu không tồn tại hoặc API đã bỏ. 400: đầu vào sai. 409: version cũ, trùng lịch, đủ chỗ hoặc trạng thái không còn hợp lệ. Lỗi trả `{message}`; Zod có thêm issues. Không gửi selector MongoDB trong body/query.

Đã bỏ `/auth/me`, PATCH profile/password, CRUD ngành, GET departments, POST users/departments/semesters/rooms, POST sessions, PATCH lịch/trạng thái buổi trực tiếp, GET lịch sử lịch/điểm danh, GET roster theo lớp, GET reports/requests và các API sửa/archive/read thông báo. STAFF không còn quyền tạo môn/lớp hoặc đăng ký thay sinh viên. Không thay bằng route tắt xác thực cho test.

## Chuyển dữ liệu và thiết lập

Backup trước khi cập nhật. Không chạy seed toàn bộ lên DB đang có dữ liệu.

```powershell
cd D:\Study\Project\myfap_clone\backend
npm run scope:preview
npm run scope:migrate
```

Migration scope thay đúng index giảng viên cũ bằng partial unique index chỉ áp dụng khi lecturer_id là ObjectId. Khởi tạo DB cũng thay index unique MajorTransfer cũ bằng index khóa một đơn PENDING hoặc APPROVED chưa áp dụng trên mỗi sinh viên. Giữ lịch sử giảng viên, đơn và điểm danh. Dữ liệu membership và nhật ký được chuyển theo quy trình db:migrate bên dưới. Đơn chuyển ngành mới được STAFF duyệt; khi duyệt, đơn giữ APPROVED/applied_at=null và được lên lịch từ kỳ kế tiếp; đến hạn mới cập nhật major_id/department_id và kết thúc membership của các môn ngoài ngành mới trong transaction.

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

`GET /reports/requests?semester_id=...` bổ sung thống kê đơn nghỉ và đơn đổi lịch/phòng trong bộ môn cho HEAD; role khác trả 403. API chuyển ngành phục vụ STUDENT gửi/xem và STAFF duyệt. Hồ sơ vẫn chỉ đọc.

## Database 17 collection và chuyển ngành theo kỳ

- `classmemberships` thay `enrollments`/`enrollmentperiods`: một document cho mỗi khoảng `starts_at`/`ends_at`; `course_id` và `semester_id` phục vụ unique index. Không còn API tự đăng ký/rút lớp. Membership chỉ phục vụ quyền truy cập, lịch học, roster và lịch sử.
- `activitylogs` thay `audits`/`sessionhistories`: `entity`, `entity_id`, `actor_id`, `action`, `request_id`, snapshot trước/sau. Dữ liệu cũ giữ ID và metadata nguồn trong `legacy_data`; thao tác buổi học mới chỉ ghi một log.
- Bỏ collection `noticereads`; nếu có dữ liệu cũ sẽ chuyển thành log `READ_NOTICE` trước khi xoá nguồn. Giữ `importbatches` và `academiclocks`.
- Khi STAFF duyệt chuyển ngành: chọn kỳ chuẩn tiếp theo tại thời điểm duyệt, ghi `effective_semester_id`, `effective_at=start_at` của kỳ, giữ `applied_at=null`. Không đổi ngành hoặc rút lớp ngay. GET danh sách trả thêm `effective_semester`.
- Chỉ một đơn PENDING/APPROVED chưa áp dụng cho mỗi sinh viên. Đến hạn, hệ thống đổi cả ngành/bộ môn và kết thúc membership các môn không thuộc ngành mới; môn chung giữ nguyên, không tự thêm lớp mới. Điểm danh/lịch sử cũ không bị xoá. Nếu ngành đích bị tắt hoặc ngành hiện tại khác ngành nguồn thì hủy việc áp dụng và ghi log.
- Áp dụng khi server khởi động, kiểm tra nền mỗi phút và trước khi xử lý request xác thực của sinh viên; xử lý bù khi server tắt qua thời điểm đầu kỳ. Các đơn cũ có `applied_at` không bị áp dụng lại hoặc đảo ngược.
- Chuyển DB cũ: dừng backend, chạy `npm run db:migrate:preview`, sau đó `npm run db:migrate`, rồi `npm run dev`. Migration kiểm tra dữ liệu đích trước khi drop đúng năm collection nguồn, có checkpoint để chạy lại sau gián đoạn. Không dùng seed để thay migration.

Phạm vi cập nhật: đã bỏ màn/API tự đăng ký môn, rút lớp, tìm lớp mở đăng ký và mở/đóng đăng ký. Danh sách sinh viên thuộc lớp được thiết lập qua seed/import; ClassMembership vẫn giữ lịch sử để xem lịch, điểm danh và áp dụng chuyển ngành.
