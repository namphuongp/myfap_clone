# Kiến trúc backend

Luồng route → validation/auth → controller → service → repository → Mongoose. Thư mục routes khai báo quyền/URL; controller lấy req.validated; service xử lý nghiệp vụ/version/transaction/audit; repository thực hiện truy vấn; model giữ schema/index.

Scope API hiện tại nằm trong [../API.md](../API.md). HEAD quản lý môn, lớp, phân công theo từng buổi và báo cáo bộ môn. STAFF gửi thông báo và duyệt đổi lịch/chuyển ngành; STUDENT đăng ký và gửi đơn chuyển ngành cho mình; profile chỉ GET.

Các service chính:

- catalog: danh mục đọc, CRUD môn HEAD và membership chương trình ngành.
- section: lớp học phần chưa cần giảng viên; mở đăng ký sau khi có lịch.
- assignment: phân công nullable theo ClassSession, đúng bộ môn, buổi tương lai; hủy Change PENDING của người cũ, giữ Leave nếu slot giữ nguyên.
- access/session: quyền theo buổi và lịch cá nhân; không dùng lecturer_id legacy của Section.
- enrollment: giới hạn 30, môn/ngành/kỳ, xung đột, ClassMembership giữ lịch sử.
- attendance/request: roster theo thời điểm; version/audit; đổi lịch chỉ qua STAFF duyệt đề xuất.
- report: tổng quan/báo cáo điểm danh theo bộ môn, người phụ trách từng buổi.
- notice/profile/auth: nháp/phát hành/đọc, profile whitelist chỉ đọc, phiên token hash.

Transaction dùng khóa học vụ chung. Không Promise.all các truy vấn trong transaction. Callback retry phải đọc/tạo lại document; save qua saveDocument trong repository. Truy vấn ngoài transaction có thể batch khi độc lập. Không nhận body thô làm MongoDB filter, không trả password/token hash.

MajorTransfer hỗ trợ workflow gửi/xem/duyệt; duyệt lên lịch chuyển ngành từ kỳ tới trong cùng transaction và ghi audit. NoticeRead giữ dữ liệu lưu trữ. SessionHistory/Audit vẫn append để bảo toàn lịch sử dù đã bỏ endpoint kỹ thuật. Migration index lecturer xử lý đúng tên/key cũ, không syncIndexes hoặc drop collection; initialize idempotent.

CLI: db:init/db:replica, seed/import/repair và scope:preview/scope:migrate/setup:session nằm trong src/scripts. Lệnh setup:session dùng HEAD hợp lệ và kiểm tra cùng bộ môn, không có route HTTP tương đương. Các danh mục tài khoản/phòng/kỳ ban đầu do seed/công cụ thiết lập quản lý.

Chạy npm test, test:workflow, test:affairs, test:import với DB test riêng theo README gốc, sau đó format:check và git diff --check. Không test trên DB myfap đang dùng.

Database mới: 17 collection; ClassMembership thay Enrollment/EnrollmentPeriod, ActivityLog thay Audit/SessionHistory, bỏ NoticeRead. Đơn chuyển ngành có hiệu lực từ kỳ tiếp theo sau khi duyệt, không đổi ngành ngay. Với DB cũ, dừng backend và chạy `npm run db:migrate` trước khi chạy ứng dụng. Xem API.md và database.md để biết quy trình và cấu trúc hiện tại.
