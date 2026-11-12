# Database MongoDB — 17 collection

| Collection       | Chức năng                                                                   |
| ---------------- | --------------------------------------------------------------------------- |
| users            | Bốn role, thông tin hồ sơ; không có ảnh                                     |
| authsessions     | Token hash và thời hạn phiên                                                |
| departments      | Bộ môn                                                                      |
| majors           | Ngành và các môn thuộc ngành                                                |
| courses          | Môn học                                                                     |
| semesters        | Học kỳ chuẩn UTC+7                                                          |
| rooms            | Phòng và sức chứa                                                           |
| sections         | Lớp học phần theo môn/kỳ; giảng viên không cố định                          |
| classsessions    | Buổi theo ngày/slot/phòng; lecturer_id nullable; attendance nhúng tối đa 30 |
| classmemberships | Khoảng thời gian sinh viên thuộc lớp; thay Enrollment/EnrollmentPeriod      |
| leaves           | Đơn nghỉ theo buổi và kết quả duyệt                                         |
| changes          | Đơn đổi lịch/phòng, snapshot và kết quả duyệt                               |
| majortransfers   | Đơn chuyển ngành, kỳ hiệu lực và thời điểm áp dụng                          |
| notices          | Thông báo học vụ                                                            |
| activitylogs     | Nhật ký chung và lịch sử buổi; thay Audit/SessionHistory                    |
| academiclocks    | Tuần tự hóa giao dịch học vụ                                                |
| importbatches    | Kiểm soát lô import, checkpoint migration                                   |

## Sinh viên thuộc lớp

ClassMembership: section_id, student_id, course_id, semester_id, starts_at, ends_at, metadata. Mỗi lần rời rồi trở lại lớp tạo khoảng mới. ends_at=null là khoảng chưa kết thúc. Unique partial ngăn hai khoảng mở của cùng cặp lớp/sinh viên và ngăn trùng môn/kỳ. Lịch/roster lấy khoảng phủ giờ bắt đầu buổi; kết thúc khoảng không xóa điểm danh cũ. Không có API tự đăng ký/rút lớp.

## Buổi học và lịch sử

Course → Section theo Semester → ClassSession theo ngày/slot. Phân công thực tế là ClassSession.lecturer_id, nullable; Section.lecturer_id chỉ giữ dữ liệu legacy. Các index chống trùng lớp/phòng/giảng viên vẫn giữ. Không có collection slots hoặc attendance riêng.

ActivityLog dùng entity/entity_id và request_id nullable để truy lịch sử. category phân biệt nguồn AUDIT/SESSION_HISTORY đã chuyển; writer mới ghi một sự kiện. legacy_data chỉ giữ metadata nguồn của dữ liệu cũ, không dùng cấp quyền.

## Chuyển ngành

STAFF duyệt chỉ lên lịch từ kỳ chuẩn tiếp theo tại thời điểm duyệt (Spring/Summer/Fall). APPROVED + applied_at=null là đã duyệt chờ áp dụng. Đến effective_at mới cập nhật User.major_id và department_id, kết thúc khoảng thuộc lớp các môn không có trong ngành mới, hủy đơn nghỉ tương lai không còn hợp lệ; môn chung giữ nguyên. Không xóa lịch sử. Chỉ một đơn PENDING hoặc APPROVED chưa áp dụng cho một sinh viên.

Server kiểm tra khi khởi động, mỗi phút và lúc xác thực sinh viên để xử lý cả trường hợp tắt server qua ranh giới kỳ. Đơn có applied_at từ trước được giữ nguyên.

## Chuyển database cũ

Dừng backend. Chạy npm run db:migrate:preview rồi npm run db:migrate trong backend. Migration chuyển và kiểm tra dữ liệu trước khi drop enrollments, enrollmentperiods, audits, sessionhistories, noticereads. Dữ liệu nguồn quan trọng được giữ trong legacy_data; NoticeRead cũ nếu có được giữ thành log READ_NOTICE. Checkpoint trong importbatches hỗ trợ chạy lại sau gián đoạn. Chỉ chạy một phiên migration với backend đã dừng. Seed và db:init không tự xóa/chuyển DB cũ.

Tham chiếu MongoDB do service kiểm tra, không phải SQL FK. Các writer học vụ phải dùng transaction/AcademicLock. Chi tiết API trong API.md.

Phạm vi cập nhật: đã bỏ màn/API tự đăng ký môn, rút lớp, tìm lớp mở đăng ký và mở/đóng đăng ký. Danh sách sinh viên thuộc lớp được thiết lập qua seed/import; ClassMembership vẫn giữ lịch sử để xem lịch, điểm danh và áp dụng chuyển ngành.
