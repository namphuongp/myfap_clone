# MyFAP Flutter

## Cấu trúc `lib/`

```text
lib/
  main.dart                         Khởi tạo ứng dụng
  core/
    academic/                        Lịch và danh sách đơn dùng chung
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

Sau khi đăng nhập, `RoleHomeRouter` đưa `STUDENT`, `LECTURER`, `HEAD`, `STAFF` tới màn hình riêng. Sinh viên có lịch theo tuần và thanh điều hướng Lịch học, Đăng ký môn, Đơn từ, Thông báo. Đăng ký môn cho xem lớp còn chỗ và lịch lớp trước khi đăng ký, xem lớp đang học và rút lớp; hai mục sau hiện là màn hình khung. Giảng viên và HEAD đều có bốn màn hình riêng; STAFF dùng màn hình chung hiện có. Khi thêm chức năng, đặt màn hình và widget vào thư mục role tương ứng; chỉ đưa phần được nhiều role dùng vào `core`.

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

Mọi role mở hồ sơ qua icon tài khoản hoặc nút Hồ sơ của tôi; cho sửa liên hệ và đổi mật khẩu, không upload ảnh. HEAD tải tổng quan bộ môn thay vì lịch. Thông báo/chuyển ngành đã có backend API; giao diện giảng viên đã tích hợp duyệt đơn nghỉ, đổi lịch/phòng và điểm danh; đơn từ/thông báo phía sinh viên còn cần tích hợp. Xem ../STUDENT_AFFAIRS.md và ../API.md.

## Chức năng giảng viên

Giảng viên có bốn màn hình riêng trong `lib/lecturer/screens/`:

- Lịch dạy: tự tải lịch theo khoảng 7 ngày, chọn ngày hoặc tuần trước/sau; hiển thị lớp, môn, phòng, ca và trạng thái theo UTC+7.
- Duyệt đơn nghỉ: lọc trạng thái, phân trang, xem tên/mã sinh viên và lý do; duyệt hoặc từ chối có ghi chú và xác nhận. Xung đột version yêu cầu đọc lại dữ liệu.
- Đổi lịch/phòng: chọn buổi tương lai, đề xuất ngày/ca/phòng và lý do; xem các đơn đã gửi và phản hồi cán bộ. Chỉ đổi phòng thì giữ nguyên ngày và ca.
- Điểm danh: chọn buổi và ghi đủ danh sách với Có mặt, Vắng mặt, Đi muộn, Vắng có phép; chỉ ghi sau khi buổi bắt đầu. Đơn nghỉ đã duyệt là ghi chú, không tự chọn trạng thái. Có xác nhận lưu, bảo vệ thay đổi chưa lưu và tải lại khi conflict.

Dữ liệu được gọi qua `lecturer/repositories/lecturer_repository.dart` và `core/api/api_client.dart`; không dùng dữ liệu giả trong ứng dụng. API vẫn phân quyền và kiểm tra nghiệp vụ tại backend. Xem `../API.md` cho hợp đồng endpoint.

Kiểm tra: `flutter analyze`, `flutter test`, `flutter build web`, `flutter build apk --debug`. Widget test dùng fixture; workflow backend dùng MongoDB replica set và database riêng có hậu tố `_test`.

## Chức năng HEAD

Bốn màn riêng: Báo cáo bộ môn, Quản lý môn học, Phân công giảng dạy và Gửi đơn chuyển phòng. Không có màn theo dõi chuyên cần từng sinh viên. HEAD chỉ thao tác trong bộ môn của tài khoản.

Báo cáo có bộ lọc kỳ/môn/giảng viên, nhóm theo lớp/môn/giảng viên và tổng hợp đơn từ. Quản lý môn có tìm kiếm, phân trang, tạo/sửa; không đổi mã đã có lớp. Phân công thực hiện trên lớp do STAFF mở, chỉ chọn giảng viên hoạt động cùng bộ môn khi lớp chưa có buổi học. Không thay đổi phân công các lớp đã có lịch.

Đơn chuyển phòng chọn buổi thuộc bộ môn, giữ ngày/ca ở dạng chỉ đọc, chọn phòng khác đủ 30 chỗ, nhập lý do và xác nhận gửi STAFF duyệt; có tab theo dõi đơn và phản hồi. Gửi đơn chưa đổi lịch. Sau STAFF duyệt, lịch sinh viên/giảng viên cập nhật phòng nhưng giữ đơn nghỉ đã duyệt.

Repository HEAD nằm ở `head/repositories/head_repository.dart`; lịch và danh sách đơn dùng chung với giảng viên qua `core/academic/`. API chi tiết trong `../API.md`. Backend test: `npm.cmd run test:head` với MONGODB_URI trỏ database mới có hậu tố `_test`; không dùng database myfap.
