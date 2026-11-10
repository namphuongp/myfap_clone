# Database MongoDB — scope MVP

Schema thực thi trong backend/src/models, registry tại models/index.js. Các tham chiếu được service kiểm tra; transaction dùng replica set và AcademicLock tuần tự hóa thao tác học vụ. Không có SQL FK.

| Model | Vai trò |
|---|---|
| Department | Bộ môn quản lý môn, giảng viên, HEAD |
| Course | Môn: code/name/department_id/active; soft disable, không xóa lịch sử |
| Semester | Kỳ cụ thể có term/year/start_at/end_at chuẩn UTC+7; giữ kỳ legacy để đối chiếu |
| Major | Ngành và course_ids phục vụ điều kiện đăng ký; HEAD chỉ thay môn trong chương trình thuộc bộ môn |
| Section | Lớp học phần của Course trong Semester, capacity=30, OPEN/CLOSED; giảng viên không cố định trên lớp |
| ClassSession | Section + ngày + slot + phòng; lecturer_id nullable là phân công của chính buổi đó; attendance nhúng tối đa 30 |
| Enrollment | Trạng thái đăng ký hiện tại của cặp sinh viên/lớp, course/semester dùng unique active |
| EnrollmentPeriod | Các khoảng starts_at/ends_at; roster và lịch quá khứ lấy theo giờ bắt đầu buổi |
| Leave / Change | Đơn nghỉ và đổi lịch/phòng có snapshot, reviewer, version, trạng thái |
| User / AuthSession | Tài khoản và phiên opaque token hash/TTL; profile chỉ đọc, không có trường ảnh |
| Room | Phòng và sức chứa |
| Notice | Nháp/phát hành, đối tượng nhận, ngày hết hạn; API chỉ tạo/phát hành/đọc |
| Audit / SessionHistory | Lịch sử append, snapshot lịch có lecturer_id; không có REST sửa/xóa hoặc endpoint riêng ngoài scope |
| AcademicLock / ImportBatch | Khóa transaction, nguồn import để chạy lại không nhân đôi |
| MajorTransfer / NoticeRead | Dữ liệu lịch sử còn giữ; không có job chuyển ngành hoặc API thay đổi/đọc mới theo workflow cũ |

Section.lecturer_id còn trong schema ở dạng optional để đọc/import document cũ, chỉ là metadata lưu trữ. API lớp không trả trường này như phân công hiện tại. Toàn bộ quyền giảng viên và báo cáo căn cứ ClassSession.lecturer_id; không tự chuyển người dạy của buổi cũ khi phân công lại.

Index ClassSession chống trùng section/room theo ngày/slot khi SCHEDULED/COMPLETED. Index session_lecturer_slot_assigned chỉ chống trùng khi lecturer_id là ObjectId, vì nhiều buổi chưa phân công có thể cùng slot ở các phòng khác nhau. Buổi CANCELLED giải phóng slot. Service còn kiểm tra giao khoảng thời gian và lịch sinh viên; lecturer_id=null bỏ kiểm tra trùng giảng viên.

Enrollment unique(section,student), unique active(student,course,semester). EnrollmentPeriod chỉ một khoảng mở mỗi cặp. Rút/đăng ký lại không xóa các khoảng trước, không xóa attendance. Một sinh viên không có class_id cố định trong User. Thay đổi lớp theo đăng ký, không phải chuyển ngành. Không có đơn chuyển lớp sinh viên trong scope hiện tại.

HEAD phân công một đợt theo danh sách buổi + version trong một transaction, kiểm tra cùng bộ môn, future/SCHEDULED/chưa attendance. Giữ nguyên mọi buổi quá khứ. Đổi người phụ trách hủy Change PENDING, giữ Leave nếu slot không đổi. Giảng viên cũ vẫn thấy yêu cầu mình đã gửi, và buổi cũ vẫn thuộc người đã dạy.

Migration scope:preview/scope:migrate thay đúng index lecturer cũ, không dùng syncIndexes, không drop collection hoặc rewrite document. Có backup trước khi chạy. Các script seed chỉ dành cho DB trống; import/repair vẫn giữ khả năng đọc lecturer_id legacy. Khi thêm writer phải đi qua service/transaction để không bỏ khóa học vụ.

4 slot cố định và kỳ 3 tháng/1 tháng nghỉ giữ nguyên. Chi tiết endpoint/payload và công cụ thiết lập buổi: [API.md](API.md).
