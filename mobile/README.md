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

Sau khi đăng nhập, `RoleHomeRouter` đưa `STUDENT`, `LECTURER`, `HEAD`, `STAFF` tới màn hình riêng. Sinh viên có lịch theo tuần và thanh điều hướng Lịch học, Đăng ký môn, Đơn từ, Thông báo. Đăng ký môn cho xem lớp còn chỗ và lịch lớp trước khi đăng ký, xem lớp đang học và rút lớp; hai mục sau hiện là màn hình khung. Các role còn lại dùng màn hình chung hiện có. Khi thêm chức năng, đặt màn hình và widget vào thư mục role tương ứng; chỉ đưa phần được nhiều role dùng vào `core`.

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

Mọi role mở hồ sơ qua icon tài khoản hoặc nút Hồ sơ của tôi; cho sửa liên hệ và đổi mật khẩu, không upload ảnh. HEAD tải tổng quan bộ môn thay vì lịch. Thông báo/chuyển ngành đã có backend API; các màn thao tác học vụ còn cần tích hợp. Xem ../STUDENT_AFFAIRS.md và ../API.md.
