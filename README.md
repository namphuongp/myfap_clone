# MyFAP — Flutter / Express / Mongoose / MongoDB

Ứng dụng học vụ dùng dữ liệu riêng, không kết nối FAP thật, không có chức năng điểm. Backend chia route → controller → service → repository → model. MongoDB cần replica set để dùng transaction.

Phạm vi backend:

- STUDENT: lịch học, đăng ký/rút môn, gửi/xem đơn nghỉ, đọc thông báo.
- LECTURER: lịch của các buổi được giao, điểm danh, duyệt nghỉ đúng buổi, gửi/xem yêu cầu đổi lịch/phòng.
- HEAD: quản lý môn/chương trình môn trong bộ môn, tạo lớp chưa phân công, mở/đóng đăng ký, phân công theo buổi, báo cáo bộ môn.
- STAFF: tạo/phát hành thông báo và duyệt đổi lịch/phòng. Mọi role có profile chỉ đọc.

Course là môn; Section là lớp học phần của một môn trong một Semester; ClassSession là buổi với ngày/slot/phòng và giảng viên nullable. Trường lecturer_id cũ của Section không còn dùng cấp quyền. Sinh viên thuộc lớp qua EnrollmentPeriod theo thời điểm. Giữ nguyên lịch sử khi đổi người phụ trách hoặc rút/đăng ký lại lớp.

Mỗi lớp 30 sinh viên. Cán bộ/HEAD không đăng ký thay sinh viên. Lớp mới CLOSED, không cần giảng viên; chỉ mở sau khi có lịch tương lai hợp lệ. Phân công chỉ sửa các buổi tương lai chưa điểm danh, không viết lại buổi cũ. Cùng một lớp có thể có nhiều giảng viên ở các buổi khác nhau.

4 slot UTC+7: 07:30–09:50, 10:00–12:20, 12:50–15:10, 15:20–17:40. Fall tháng 9–11, Spring 1–3, Summer 5–7; nghỉ tháng 12/4/8. Đổi ngày/slot làm đơn nghỉ cũ hết hiệu lực; đổi phòng vẫn giữ. Duyệt nghỉ chỉ thêm note, không tự ghi Có mặt.

## Chạy cục bộ

Từ D:\Study\Project\myfap_clone:

```powershell
.\start-local.ps1
```

Script chạy MongoDB riêng cổng 27018 (myfap-rs) và API 3000; không ảnh hưởng MongoDB 27017 của máy. Khi MongoDB đã chạy, có thể dùng terminal backend: npm run dev. Chỉ chạy một API trên cổng 3000.

Máy mới: cài Node >=22.12, MongoDB replica set hoặc Atlas, Flutter. Trong backend chạy npm ci; copy .env.example thành .env nếu chưa có; db:replica chỉ dành cho local; db:init; seed chỉ dành cho DB trống hoặc bộ tài khoản demo gốc. Có Docker Compose ở thư mục gốc. Môi trường triển khai cần DB account/HTTPS, không commit URI có credential.

```powershell
cd mobile
flutter pub get
flutter run -d chrome --web-hostname=localhost --web-port=5173
# Android Emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
# Windows khi đã cài bộ build desktop
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

Chrome dùng localhost:3000, cổng frontend 5173 khớp CORS_ORIGINS. Android Emulator dùng 10.0.2.2, máy thật dùng IP LAN. Tài khoản demo student/lecturer/head/staff@myfap.local, mật khẩu Demo@12345678. Không chạy seed trên database có tài khoản thật.

## Seed dữ liệu demo một lượt

Khi MongoDB đã chạy, từ thư mục backend:

```powershell
npm run seed
```

Lệnh duy nhất tạo/bổ sung tài khoản bốn role, bốn sinh viên mẫu, ngành/môn demo, hai lớp PRM393/DBI202, phòng, học kỳ, đăng ký và lịch theo ngày chạy (UTC+7). Gán giảng viên ở từng buổi, không dựa vào giảng viên cũ của lớp. Trong tháng nghỉ, lịch thuộc kỳ kế tiếp. Không cần chạy seed học vụ hoặc seed giảng viên/sinh viên riêng. Alias seed:affairs cũ cũng gọi lệnh seed tổng.

Chạy lại không đổi mật khẩu, không tự đăng ký lại sinh viên đã rút, không ghi đè buổi hoặc điểm danh cũ. Sinh viên bổ sung vào DB demo đã có chỉ tham gia từ thời điểm seed, để giữ roster lịch sử. Seed từ chối DB chứa tài khoản ngoài bộ demo. Các bước dùng transaction riêng và có thể chạy lại nếu lần trước bị gián đoạn. SEED_PASSWORD trong .env cần ít nhất 12 ký tự và tối đa 72 byte. Seed không xóa dữ liệu; không tự tạo đơn hoặc thông báo đã duyệt/phát hành.

## Cập nhật scope và giữ dữ liệu cũ

Backup trước; .local/, .env, node_modules/build bị loại khỏi Git.

```powershell
cd backend
npm run scope:preview
npm run scope:migrate
```

Chỉ thay index giảng viên cũ bằng unique index áp dụng cho lecturer_id là ObjectId. Giữ nguyên document, giảng viên từng buổi, version, đăng ký, đơn, điểm danh và audit. Startup cũng bảo đảm index mới. MajorTransfer/NoticeRead cũ còn lưu trữ, không còn route ghi hoặc job chuyển ngành.

API ngoài scope đã gỡ: sửa profile/mật khẩu, chuyển ngành/CRUD ngành, quản trị tài khoản/phòng/kỳ/bộ môn, xếp/sửa lịch trực tiếp qua REST, endpoint lịch sử kỹ thuật, đăng ký thay sinh viên và báo cáo đơn. Giữ danh mục đọc thực sự phục vụ form. HEAD có GET majors để chọn chương trình khi quản lý môn; không có CRUD ngành.

Lịch ban đầu được seed/import hoặc chuẩn bị bằng công cụ, không mở thêm màn quản trị lịch:

```powershell
npm run setup:session -- --head=HEAD_ID --section=SECTION_ID --room=ROOM_ID --date=2026-11-20 --slot=1
```

Thay ID thật; lệnh tạo buổi chưa phân công, kiểm tra quyền bộ môn và xung đột, giữ audit. Sau đó dùng PUT assignments và PATCH section/status. Công cụ import:legacy, slots:preview/repair, academics:preview/normalize vẫn giữ cho dữ liệu cũ; xem database.md và API.md.

## Kiểm thử

```powershell
cd backend
npm test
$stamp=Get-Date -Format yyyyMMddHHmmss
$env:MONGODB_URI="mongodb://127.0.0.1:27018/myfap_workflow_${stamp}_test?replicaSet=myfap-rs"
npm run test:workflow
$env:MONGODB_URI="mongodb://127.0.0.1:27018/myfap_affairs_${stamp}_test?replicaSet=myfap-rs"
npm run test:affairs
$env:MONGODB_URI="mongodb://127.0.0.1:27018/myfap_import_${stamp}_test?replicaSet=myfap-rs"
npm run test:import
Remove-Item Env:MONGODB_URI
npm run format:check
```

Các suite MongoDB chỉ dùng DB riêng trống có hậu tố _test, không chạy trên myfap. Test không xóa DB sau khi chạy. Có kiểm tra phân công đồng thời/rollback, null index, lịch sử người dạy/sinh viên, 30 chỗ, đơn, thông báo, scope và bảo mật. Trong mobile: flutter analyze, flutter test. Fixture/widget test không thay thế kiểm thử thiết bị thật.

Tài liệu: [API](API.md), [Request mẫu](requests.http), [Database](database.md), [Kiến trúc backend](backend/README.md), [Giao diện giảng viên](LECTURER_UI.md), [Phạm vi học vụ](STUDENT_AFFAIRS.md).

### HEAD sau tích hợp main

HEAD vẫn có bốn màn riêng. Môn học dùng nghiệp vụ main, gồm ngành áp dụng và trạng thái hoạt động. Phân công chuyển sang từng buổi học, dùng version của buổi và lý do; giữ kiểm tra xung đột, lịch sử và hủy đề xuất cũ khi đổi người phụ trách. Màn chuyển phòng giữ nguyên ngày/ca và chờ STAFF duyệt. Giữ nguyên giao diện sinh viên, giảng viên và hồ sơ chỉ đọc từ main. `npm.cmd run test:head` kiểm tra luồng kết hợp trên database test riêng.
