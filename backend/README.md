# Kiến trúc backend

Luồng route → validation/auth → controller → service → repository → Mongoose. Thư mục routes khai báo quyền/URL; controller lấy req.validated; service xử lý nghiệp vụ/version/transaction/audit; repository thực hiện truy vấn; model giữ schema/index.

Scope API hiện tại nằm trong [../API.md](../API.md). HEAD quản lý môn, lớp, phân công theo từng buổi và báo cáo bộ môn. STAFF gửi thông báo và duyệt đổi lịch/chuyển ngành; STUDENT gửi đơn chuyển ngành cho mình; profile chỉ GET.

Các service chính:

- catalog: danh mục đọc, CRUD môn HEAD và membership chương trình ngành.
- section: lớp học phần chưa cần giảng viên; danh sách sinh viên do seed/import thiết lập.
- assignment: phân công nullable theo ClassSession, đúng bộ môn, buổi tương lai; hủy Change PENDING của người cũ, giữ Leave nếu slot giữ nguyên.
- access/session: quyền theo buổi và lịch cá nhân; không dùng lecturer_id legacy của Section.
- attendance/request: roster theo thời điểm; version/audit; đổi lịch chỉ qua STAFF duyệt đề xuất.
- report: tổng quan/báo cáo điểm danh theo bộ môn, người phụ trách từng buổi.
- notice/profile/auth: nháp/phát hành/đọc, profile whitelist chỉ đọc, phiên token hash.

Transaction dùng khóa học vụ chung. Không Promise.all các truy vấn trong transaction. Callback retry phải đọc/tạo lại document; save qua saveDocument trong repository. Truy vấn ngoài transaction có thể batch khi độc lập. Không nhận body thô làm MongoDB filter, không trả password/token hash.

MajorTransfer hỗ trợ workflow gửi/xem/duyệt; duyệt lên lịch chuyển ngành từ kỳ tới trong cùng transaction và ghi audit. ActivityLog giữ nhật ký chung và lịch sử buổi; NoticeRead đã được bỏ. Migration index giảng viên chỉ thay đúng index cần thiết. Migration collection có bước xác minh đích trước khi xoá nguồn.

CLI: db:init/db:replica, seed/import/repair và scope:preview/scope:migrate/setup:session nằm trong src/scripts. Lệnh setup:session dùng HEAD hợp lệ và kiểm tra cùng bộ môn, không có route HTTP tương đương. Các danh mục tài khoản/phòng/kỳ ban đầu do seed/công cụ thiết lập quản lý.

Chạy npm test, test:workflow, test:affairs, test:import với DB test riêng theo README gốc, sau đó format:check và git diff --check. Không test trên DB myfap đang dùng.

Database mới: 17 collection; ClassMembership thay Enrollment/EnrollmentPeriod, ActivityLog thay Audit/SessionHistory, bỏ NoticeRead. Đơn chuyển ngành có hiệu lực từ kỳ tiếp theo sau khi duyệt, không đổi ngành ngay. Với DB cũ, dừng backend và chạy `npm run db:migrate` trước khi chạy ứng dụng. Xem API.md và database.md để biết quy trình và cấu trúc hiện tại.

Phạm vi cập nhật: đã bỏ màn/API tự đăng ký môn, rút lớp, tìm lớp mở đăng ký và mở/đóng đăng ký. Danh sách sinh viên thuộc lớp được thiết lập qua seed/import; ClassMembership vẫn giữ lịch sử để xem lịch, điểm danh và áp dụng chuyển ngành.
