# MyFAP Flutter và Express MySQL

Backend cho 4 vai trò STUDENT, LECTURER, HEAD, STAFF. Dữ liệu giả lập, không kết nối FAP thật. Không có chức năng điểm. Yêu cầu trong chat được ưu tiên hơn thiết kế MySQL cũ trong báo cáo.

## Chạy trên Windows

Trong workspace đã bàn giao, MySQL portable đã khởi tạo ở `.local/mysql-runtime` (runtime cục bộ được loại khỏi Git), backend/.env hiện dùng cổng 13379. API demo đã được chạy ở 3000. Sau khi tắt/mở máy, từ thư mục dự án này chạy `powershell -ExecutionPolicy Bypass -File .\start-local.ps1` để mở lại cả hai tiến trình. Script dùng runtime cục bộ trong dự án; khi chuyển dự án sang máy khác dùng Docker/MySQL bên dưới, cấu hình lại .env từ .env.example (cổng 3307).

Cần Node.js >=22.12, Flutter SDK, Android SDK và MySQL 8.0.16+ (khuyến nghị 8.4). Mở thư mục này trong VS Code.

```powershell
cd D:\Study\Project\myfap_clone
docker compose up -d --wait
cd backend
Copy-Item .env.example .env # Chỉ lần đầu, giữ file cấu hình riêng nếu đã có
npm ci
npm run migrate
npm run seed
npm run dev
```

Nếu Docker Desktop chưa chạy: mở Docker Desktop và đợi engine sẵn sàng. Nếu dùng MySQL có sẵn: tạo database trống `myfap` với charset `utf8mb4`, tạo tài khoản riêng có quyền trên database này và sửa `backend/.env`; bỏ qua lệnh Docker. Migration không xóa bảng, chỉ dùng cho database trống. DDL MySQL tự commit: nếu migration lỗi giữa chừng cần kiểm tra bảng đã tạo trước khi tiếp tục, không tự chạy lại trên dữ liệu thật.

Compose dùng cổng máy chủ 3307 để tránh MySQL 3306 đang có. Mật khẩu trong compose/.env.example chỉ phục vụ máy phát triển. Nếu đổi mật khẩu compose, đồng thời đổi backend/.env; mật khẩu khởi tạo container chỉ có hiệu lực khi volume còn trống. `docker compose down` giữ dữ liệu volume; không dùng `down -v` nếu muốn giữ dữ liệu.

Mật khẩu mẫu `Demo@12345678` (đổi SEED_PASSWORD trước seed nếu cần). Email: `student@myfap.local`, `lecturer@myfap.local`, `head@myfap.local`, `staff@myfap.local`. Seed không chạy nếu đã có người dùng. Lịch mẫu gồm một buổi trước và một buổi sau thời điểm seed, cho phép thử điểm danh và xin nghỉ.

Trong terminal thứ hai:

```powershell
cd D:\Study\Project\myfap_clone\mobile
flutter doctor
flutter pub get
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Android emulator dùng `10.0.2.2`; máy thật dùng IP LAN của máy chạy backend và cấu hình firewall cho mạng riêng nếu cần. Chỉ bản Android debug cho phép HTTP. Bản release phải dùng HTTPS. Flutter hiện là khung phát triển gồm đăng nhập, đăng xuất, xem lịch; UI duyệt đơn/điểm danh cần xây tiếp dựa trên API đã có. Chưa có APK được kiểm thử trên thiết bị.

## Phân quyền và quy tắc

| Vai trò | Quyền |
|---|---|
| STUDENT | Xem lịch, điểm danh bản thân; gửi/xem đơn nghỉ của mình |
| LECTURER | Xem lịch/lớp được phân công; điểm danh; duyệt nghỉ; gửi đơn đổi lịch/phòng |
| HEAD | Xem lịch, đơn, điểm danh và thống kê trong bộ môn; không duyệt |
| STAFF | Cấp tài khoản, phòng, lớp, danh sách lớp, tạo lịch; xem toàn trường; duyệt đổi lịch/phòng |

- Không đăng ký công khai. Mật khẩu bcrypt, token ngẫu nhiên 256 bit; DB chỉ lưu SHA-256 của token. Logout thu hồi phiên trên server. Phiên mặc định 8 giờ. Chưa có quên mật khẩu/refresh token; app mở lại yêu cầu đăng nhập.
- Cả email và payload đều được kiểm tra chặt; truy vấn Knex có bind parameter; không đưa đối tượng người dùng trực tiếp vào SQL. Giới hạn tốc độ và kích thước JSON. Không bật proxy trust tùy tiện.
- Gửi/duyệt đồng ý đơn nghỉ trước buổi học. Một sinh viên có một đơn trên một buổi; bản MVP chưa hỗ trợ gửi lại đơn bị từ chối/rút đơn. Ghi chú `Nghỉ có phép` lấy trực tiếp từ đơn APPROVED, không đổi thành PRESENT; chưa ghi nhận vẫn là NOT_RECORDED. Khi điểm danh, giảng viên chọn PRESENT/ABSENT/LATE/EXCUSED độc lập với ghi chú.
- Điểm danh chỉ khi buổi đã bắt đầu, phải gửi đủ danh sách lớp, không có ID trùng/lạ. Giảng viên có thể sửa sau buổi học bằng version mới; chưa có hạn khóa điểm danh theo quy chế nhà trường.
- Một buổi chỉ có một yêu cầu đổi lịch PENDING. Chỉ đổi buổi tương lai. Cán bộ duyệt mới thay đổi lịch thực, kiểm tra lại trùng phòng/giảng viên/sinh viên và sức chứa ngay lúc duyệt. Khoảng buổi học tối đa 12 giờ; hai buổi tiếp giáp được phép.
- Mọi ghi học vụ khóa cùng một dòng trong transaction InnoDB, kèm version và nhật ký. Phù hợp MVP, tuần tự hóa các thao tác ghi để giữ tính đúng. Khi tải lớn có thể tách khóa theo ngày/tài nguyên sau khi có kiểm thử đồng thời.
- Tạo lớp -> thêm sinh viên -> xếp lịch. MVP chặn thêm sinh viên khi lớp đã có buổi học, tránh phá lịch và dữ liệu điểm danh. Chưa có màn hình/endpoint sửa/xóa hồ sơ, đổi giảng viên hay hủy buổi; không sửa SQL thủ công lúc app đang chạy.
- Thời gian API yêu cầu ISO 8601 có Z/offset; lưu UTC ở DATETIME(3), Flutter hiển thị giờ địa phương.
- Nếu buổi được đổi lịch, đơn nghỉ vẫn gắn cùng mã buổi học; ghi chú được giữ. Đây là hành vi MVP, có thể cần yêu cầu sinh viên xác nhận lại ở phiên bản sau.

## Các tệp chính

- `backend/src/app.js`: route, kiểm tra payload, phân quyền.
- `backend/src/core.js`: phiên đăng nhập, phạm vi dữ liệu, version, transaction, audit.
- `backend/src/scheduling.js`: kiểm tra xung đột lịch và sức chứa.
- `backend/schema.sql`: schema mới; `src/migrate.js`, `src/seed.js`: khởi tạo.
- `mobile/lib/main.dart` -> `mobile/lib/api_client.dart` -> REST API -> MySQL.
- [API.md](API.md): đường dẫn và ví dụ payload. [requests.http](requests.http): gọi API nhanh bằng REST Client.
- [database.md](database.md): ERD mới và các quyết định dữ liệu.

## Kiểm thử

```powershell
cd backend
npm test
cd ..\mobile
flutter analyze
flutter test
```

`npm test` có 8 bài không cần DB; bài workflow MySQL mặc định SKIP. Chạy tích hợp trên database riêng trống `myfap_test` đã tạo sẵn và user có quyền tương ứng:

```powershell
cd backend
$env:DB_NAME = 'myfap_test'
$env:RUN_MYSQL_TESTS = '1'
node --env-file=.env --test --test-concurrency=1
Remove-Item Env:RUN_MYSQL_TESTS
Remove-Item Env:DB_NAME
```

Test tích hợp tạo schema và dữ liệu trong database test, không dọn/xóa khi kết thúc để giữ bằng chứng. Lần chạy tiếp theo cần một database test trống. Không dùng database triển khai để thử nghiệm. Tài liệu tham chiếu: [Knex transaction](https://knexjs.org/guide/transactions.html), [MySQL InnoDB](https://dev.mysql.com/doc/refman/8.4/en/innodb-introduction.html), [Flutter Android](https://docs.flutter.dev/platform-integration/android/setup).

## Kết quả xác minh bàn giao

- Backend: 8/8 kiểm tra bảo mật/validation đạt, không cần DB.
- Workflow tích hợp MySQL 8.0.46 portable, database riêng myfap_test: đạt. Bao gồm login đủ 4 role, chặn sinh viên tạo lịch, HEAD đọc thống kê, gửi/duyệt nghỉ đúng quyền, ghi chú Nghỉ có phép, chặn điểm danh buổi tương lai, hai cập nhật cùng version chỉ một thành công, duyệt đổi phòng, chặn trùng lịch và logout vô hiệu token.
- Database demo myfap: migration và seed đã chạy thành công riêng với database test.
- Flutter analyze: không có lỗi; widget test kiểm tra form đăng nhập: 1/1 đạt. Chưa build APK, chưa xác minh gọi API trên thiết bị/emulator, chưa đo hiệu năng.
- Docker Desktop chưa khởi động engine trong phiên này; compose được cung cấp nhưng không tính là đã kiểm chứng chạy container.
