# MyFAP Flutter

## Cấu trúc `lib/`

```text
lib/
  main.dart                         Khởi tạo ứng dụng
  core/
    api/api_client.dart              Gọi API và lưu token
    auth/screens/login_screen.dart   Đăng nhập
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

Sau khi đăng nhập, `RoleHomeRouter` đưa `STUDENT`, `LECTURER`, `HEAD`, `STAFF` tới màn hình riêng. Mỗi màn hình hiện dùng widget lịch chung để giữ chức năng đang có. Khi thêm chức năng, đặt màn hình và widget vào thư mục role tương ứng; chỉ đưa phần được nhiều role dùng vào `core`.

## Chạy trên Android emulator

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Backend cần chạy tại `http://localhost:3000/api` trên máy phát triển.
