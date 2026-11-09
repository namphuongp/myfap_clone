# Học vụ và profile MyFAP

## Phạm vi đã triển khai

- STUDENT: API xem lịch, đăng ký môn trong ngành, gửi nghỉ/chuyển ngành, đọc thông báo; profile xem/sửa liên hệ, đổi mật khẩu.
- LECTURER: lịch dạy, duyệt nghỉ đúng lớp, gửi đổi lịch/phòng, điểm danh; profile.
- HEAD: báo cáo bộ môn và profile. Không còn truy cập roster, lịch cá nhân/lớp hoặc danh sách đơn. Danh mục bộ môn/môn/học kỳ chỉ phục vụ bộ lọc báo cáo.
- STAFF: thông báo, duyệt đổi lịch/phòng/chuyển ngành, profile; giữ quyền quản trị người dùng, ngành/chương trình, học kỳ, lớp, phòng và lịch để vận hành.

Backend giữ cấu trúc route → controller → service → repository → model. Các chức năng học vụ dùng transaction, version, audit và kiểm tra quyền theo dữ liệu.

## Học kỳ

| Kỳ | Thời gian học | Nghỉ sau kỳ |
|---|---|---|
| Fall | 01/09–hết 30/11 | Tháng 12 |
| Spring | 01/01–hết 31/03 | Tháng 4 |
| Summer | 01/05–hết 31/07 | Tháng 8 |

Một năm học bắt đầu Fall, sau đó Spring và Summer năm sau. Các mốc theo UTC+7. API tạo kỳ nhận term/year, tự tính start_at/end_at; không nhập ngày tự do. Buổi học phải nằm trong kỳ. Bốn slot vẫn là 07:30–09:50, 10:00–12:20, 12:50–15:10, 15:20–17:40.

Để chuyển metadata cũ sang các kỳ chuẩn, sau khi backup dùng:

```powershell
cd D:\Study\Project\myfap_clone\backend
npm run academics:preview
npm run academics:normalize
```

Lệnh dùng lịch thực của lớp để xác định kỳ. Lớp có buổi trong tháng nghỉ hoặc nhiều kỳ sẽ bị chặn để cán bộ sửa/tách lớp; không tự dời buổi. Giữ semester cũ với legacy=true, cập nhật tham chiếu lớp/đăng ký trong transaction và giữ lịch sử. Database demo hiện tại đã chuyển sang FALL-2026; không xóa đăng ký hay điểm danh.

## Chương trình ngành và chuyển ngành

Major là ngành, Department là bộ môn; hai khái niệm được tách riêng. Major.course_ids xác định môn thuộc ngành; một môn có thể là môn chung của nhiều ngành. STAFF gán ngành ban đầu cho tài khoản chưa có ngành; sau đó phải qua quy trình chuyển ngành. Sinh viên chưa có ngành cần cán bộ cập nhật trước khi đăng ký môn.

Khi gửi đơn, server chụp ngành xuất phát/đích và lấy kỳ kế tiếp. Duyệt không thay đổi ngành ngay. Đến đầu kỳ, job và xác thực đồng bộ áp dụng một lần; đổi ngành/bộ môn, đóng đăng ký môn cũ không có trong ngành mới ở kỳ hiệu lực trở đi. Các khoảng đăng ký/điểm danh quá khứ và môn chung được giữ. Rút đăng ký tự hủy các đơn nghỉ tương lai liên quan. Kết quả có audit và applied_at.

Ví dụ: gửi trong Fall 2026, duyệt trước 01/01/2027 → áp dụng đầu Spring 2027. Nếu PRM393 chỉ có ở ngành cũ thì lớp PRM393 Spring 2027 bị rút; lớp PRM393 Fall 2026 giữ nguyên lịch sử; môn chung của hai ngành vẫn học tiếp. Trước hiệu lực, đăng ký theo ngành hiện tại; sau hiệu lực theo ngành mới.

Chỉ có một đơn chờ/chưa áp dụng cho mỗi sinh viên. Đơn chưa duyệt mà kỳ hiệu lực đã bắt đầu phải rút/gửi lại; không tự dời ngày hiệu lực hoặc duyệt hồi tố. HEAD chỉ nhận số lượng đơn trong báo cáo, không đọc chi tiết lý do cá nhân.

## Thông báo

STAFF tạo nháp, kiểm tra đối tượng rồi phát hành. Audience: tất cả sinh viên, một số bộ môn, hoặc một số ngành. STUDENT chỉ thấy bản đã phát hành, chưa hết hạn và đúng ngành/bộ môn hiện tại. Đánh dấu đọc chỉ lưu lần đầu. Nội dung đã phát hành không sửa trực tiếp; lưu trữ rồi phát hành bản mới. Chưa tích hợp email/push.

## Profile Flutter

Mọi role mở bằng icon tài khoản trên thanh trên hoặc nút Hồ sơ của tôi sau đăng nhập. Màn hình có avatar chữ cái đầu tên, tên/mã/email/vai trò/bộ môn; sinh viên có thêm ngành học. Không thêm trường ảnh, file ảnh hay upload avatar.

Cho sửa số điện thoại, địa chỉ, ngày sinh; không tự sửa tên, email, mã, role, bộ môn/ngành. Lưu dùng version để chặn ghi đè. Đổi mật khẩu cần mật khẩu hiện tại; thu hồi toàn bộ phiên và quay về đăng nhập. Flutter có trạng thái tải/lỗi/thử lại, khóa điều khiển khi lưu và xử lý conflict.

Luồng: `mobile/lib/core/profile/screens/profile_screen.dart` → `mobile/lib/core/profile/repositories/profile_repository.dart` → `mobile/lib/core/api/api_client.dart` → `profile.routes/controller/service` → repository → Mongoose.

Flutter hiện có đăng nhập, xem lịch, tổng quan HEAD và profile. Các thao tác thông báo/đơn chuyển ngành mới có API để tích hợp tiếp giao diện tương ứng; không tính các API này là đã có đầy đủ màn quản trị Flutter.

## Dữ liệu mẫu và kiểm thử

`npm run seed` dành cho DB trống, tạo ngành SE và sinh viên demo đã có ngành. Với database demo cũ được import, `npm run seed:affairs` chỉ nhận đúng tài khoản `Demo STUDENT`/`Demo STAFF` tại myfap.local, tạo SE-DEMO/AI-DEMO và gán ngành nếu còn trống. Không tự gán ngành cho tài khoản thật, không ghi đè ngành đã có.

Chạy các bài test trên DB riêng trống có hậu tố _test:

```powershell
npm test
$stamp=Get-Date -Format yyyyMMddHHmmss
$env:MONGODB_URI="mongodb://127.0.0.1:27018/myfap_affairs_${stamp}_test?replicaSet=myfap-rs"
npm run test:affairs
# Dùng tên DB mới cho từng suite tiếp theo
$env:MONGODB_URI="mongodb://127.0.0.1:27018/myfap_workflow_${stamp}_test?replicaSet=myfap-rs"
npm run test:workflow
$env:MONGODB_URI="mongodb://127.0.0.1:27018/myfap_import_${stamp}_test?replicaSet=myfap-rs"
npm run test:import
Remove-Item Env:MONGODB_URI
```

Test học vụ có kiểm tra 4 role/profile, chặn sửa quyền/ảnh, thông báo đúng đối tượng/idempotence, duyệt đồng thời, áp dụng đúng đầu kỳ, giữ môn chung và lịch sử, báo cáo có phạm vi, đổi mật khẩu thu hồi phiên. Thời điểm đầu kỳ được truyền có kiểm soát trong test service trên DB fixture; không phải đã chờ đến kỳ thực hoặc chạy production.

Trong mobile chạy `flutter analyze` và `flutter test`. Widget test profile dùng API fixture, bao phủ 4 role/avatar chữ, lưu/version, lỗi/nhập sai và đổi mật khẩu. Ảnh kiểm tra layout được render từ Flutter test với font thật; chưa thay thế kiểm thử trên thiết bị/emulator hoặc APK release.
