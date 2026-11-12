# MyFAP Flutter

## Cấu trúc `lib/`

```text
lib/
  main.dart                         Khởi tạo ứng dụng
  core/
    api/api_client.dart              Gọi API và lưu token
    auth/screens/login_screen.dart   Đăng nhập
    profile/screens/                 Hồ sơ dùng chung, avatar chữ
    profile/repositories/            API hồ sơ và mật khẩu
    navigation/role_home_router.dart Chọn màn hình theo role
    widgets/schedule_home_screen.dart Màn hình lịch hiện dùng chung
    utils/                           Tiện ích dùng chung
  student/                            Phần của Ngọc
    screens/  widgets/  utils/
  lecturer/
    screens/  widgets/  utils/
  head/
    screens/  widgets/  utils/
  staff/
    screens/  widgets/  utils/
```

Sau khi đăng nhập, `RoleHomeRouter` đưa `STUDENT`, `LECTURER`, `HEAD`, `STAFF` tới màn hình theo role. Sinh viên có lịch theo tuần, đăng ký/rút lớp, gửi/theo dõi đơn xin nghỉ và chuyển ngành, xem/tìm kiếm thông báo học vụ theo phạm vi được nhận. Giảng viên có lịch dạy, điểm danh và xử lý đơn; HEAD có màn quản lý môn/lớp và báo cáo; STAFF có màn thông báo và duyệt đổi lịch/phòng/chuyển ngành. Khi thêm chức năng, đặt màn hình và widget vào thư mục role tương ứng; chỉ đưa phần được nhiều role dùng vào `core`.

Backend hiện dùng trạng thái lớp `OPEN/CLOSED` để cho phép đăng ký, chưa có mốc thời gian mở và đóng đăng ký. Nếu cần đợt đăng ký theo giờ, backend phải lưu mốc thời gian và kiểm tra khi nhận yêu cầu đăng ký; chỉ đếm ngược ở Flutter không đủ để chặn đăng ký ngoài thời gian.

## Chạy trên Android emulator

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Backend cần chạy tại `http://localhost:3000/api` trên máy phát triển.

## Chạy trên Chrome (không cần máy ảo)

Từ thư mục gốc, mở terminal thứ nhất để chạy API và MongoDB:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start-local.ps1
```

Mở terminal thứ hai:

```powershell
cd mobile
flutter pub get
flutter run -d chrome --web-hostname=localhost --web-port=5173
```

Web mặc định gọi `http://localhost:3000/api`. Cổng `5173` khớp với `CORS_ORIGINS` trong `backend/.env.example`. Nếu đổi cổng web, cập nhật `CORS_ORIGINS` trong `backend/.env` rồi khởi động lại API. Khi đang chạy, nhấn `r` trong terminal Flutter để hot reload.

Mọi role mở hồ sơ qua icon tài khoản hoặc nút Hồ sơ của tôi; chỉ xem thông tin, avatar là chữ đầu tên, không có chỉnh sửa/đổi mật khẩu hoặc upload ảnh. HEAD tải tổng quan bộ môn thay vì lịch. Giảng viên có trang chủ, lịch dạy, điểm danh, duyệt nghỉ, yêu cầu đổi lịch/phòng và theo dõi trạng thái; STAFF có soạn/phát hành thông báo và duyệt đổi lịch/phòng/chuyển ngành. Xem [Giao diện giảng viên](../LECTURER_UI.md), ../STUDENT_AFFAIRS.md và ../API.md.

HEAD có bốn màn riêng và dùng core/academic cho lịch/danh sách đơn. Phân công thực hiện qua API theo buổi của main; các màn giảng viên và sinh viên giữ nguyên từ main. Không có màn Theo dõi chuyên cần cho HEAD. Course form hỗ trợ major_ids và trạng thái hoạt động, dùng cùng nghiệp vụ main qua alias /head/courses.

Database mới: 17 collection; ClassMembership thay Enrollment/EnrollmentPeriod, ActivityLog thay Audit/SessionHistory, bỏ NoticeRead. Đơn chuyển ngành có hiệu lực từ kỳ tiếp theo sau khi duyệt, không đổi ngành ngay. Với DB cũ, dừng backend và chạy `npm run db:migrate` trước khi chạy ứng dụng. Xem API.md và database.md để biết quy trình và cấu trúc hiện tại.
