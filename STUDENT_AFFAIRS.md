# Phạm vi học vụ hiện tại

Các màn theo nhóm: Phương — lịch dạy, điểm danh, duyệt nghỉ, lịch sử yêu cầu. Duy — báo cáo bộ môn, quản lý môn, phân công (HEAD), form đổi lịch/phòng (LECTURER). Sơn — thông báo, duyệt đổi lịch/phòng/chuyển ngành (STAFF), profile chỉ đọc mọi role. Ngọc — lịch học, xin nghỉ, gửi đơn chuyển ngành, đọc thông báo, đăng nhập.

Backend chỉ mở API phục vụ các màn và dữ liệu phụ trợ cần thiết. Chi tiết đầy đủ: [API.md](API.md); nguồn dữ liệu và lịch sử: [database.md](database.md).

- Profile chỉ GET, whitelist tên/mã/email/role/ngành, không có liên hệ/bộ môn/ảnh. Gỡ PATCH profile/password ở backend, không chỉ ẩn nút Flutter.
- Giảng viên được gán trên từng ClassSession. Lớp tạo chưa có giảng viên; các buổi khác nhau có thể do người khác dạy. Phân công chỉ sửa buổi tương lai, có version/transaction/audit.
- Sinh viên được xếp vào lớp theo môn/kỳ; ClassMembership bảo toàn roster/lịch/điểm danh khi sinh viên thay đổi lớp. Môn phải hoạt động và thuộc chương trình ngành của sinh viên. HEAD có thể chọn major_ids khi tạo/sửa môn trong bộ môn; không có CRUD ngành. Sinh viên gửi đơn chuyển ngành, STAFF duyệt lên lịch từ kỳ tới; đến hạn mới cập nhật ngành/bộ môn và danh sách lớp trong transaction.
- Đơn nghỉ theo chính ngày/slot đã gửi; duyệt thêm ghi chú, không tự đổi thành PRESENT. Chỉ đổi phòng giữ đơn, đổi slot/ngày làm đơn cũ hết hiệu lực. Giảng viên chỉ duyệt buổi đang được giao.
- STAFF tạo nháp và phát hành thông báo theo ALL_STUDENTS/DEPARTMENT/MAJOR; sinh viên chỉ thấy bản phù hợp chưa hết hạn. Không có REST sửa/archive/read hoặc push/email trong scope.
- Báo cáo HEAD theo phạm vi bộ môn, thống kê giảng viên từ từng buổi. Không có báo cáo đơn riêng.

Năm học bắt đầu Fall (9–11), Spring (1–3), Summer (5–7); nghỉ tháng 12/4/8. 4 slot giữ 07:30–09:50, 10:00–12:20, 12:50–15:10, 15:20–17:40 theo UTC+7.

Chuyển scope có backup và kiểm tra từng document cũ; scope:preview/migrate chỉ thay index giảng viên để cho phép nhiều buổi chưa phân công cùng slot, không thay dữ liệu nghiệp vụ. Lịch ban đầu chuẩn bị bằng seed/import/setup:session; không mở thêm màn/API quản trị lịch ngoài phạm vi.

Kiểm thử backend gồm npm test, test:workflow, test:affairs, test:import trên DB riêng _test; xem README. Luồng chuyển ngành mới kiểm tra quyền, gửi đơn, duyệt, cập nhật major_id và audit; dữ liệu APPROVED cũ vẫn không tự áp dụng khi đăng nhập. Widget test Flutter dùng fixture.

Database mới: 17 collection; ClassMembership thay Enrollment/EnrollmentPeriod, ActivityLog thay Audit/SessionHistory, bỏ NoticeRead. Đơn chuyển ngành có hiệu lực từ kỳ tiếp theo sau khi duyệt, không đổi ngành ngay. Với DB cũ, dừng backend và chạy `npm run db:migrate` trước khi chạy ứng dụng. Xem API.md và database.md để biết quy trình và cấu trúc hiện tại.

Phạm vi cập nhật: đã bỏ màn/API tự đăng ký môn, rút lớp, tìm lớp mở đăng ký và mở/đóng đăng ký. Danh sách sinh viên thuộc lớp được thiết lập qua seed/import; ClassMembership vẫn giữ lịch sử để xem lịch, điểm danh và áp dụng chuyển ngành.
