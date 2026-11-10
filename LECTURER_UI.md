# Giao diện giảng viên

Frontend Flutter dùng bố cục tham khảo myFAP: header/nav xanh navy, điểm nhấn cam, nền sáng, thẻ trắng bo góc và avatar chữ. Chỉ bổ sung luồng giảng viên đã thống nhất; không thêm điểm, thi, học phí, chat, push hay QR. Profile tiếp tục dùng API chung, không có ảnh.

## Các màn và API

| Màn | Hành vi | API |
|---|---|---|
| Trang chủ | Thẻ chức năng và tài khoản; không có tổng quan/buổi dạy gần đây | Không tải lịch/đơn tại trang chủ |
| Lịch dạy | Hiển thị kỳ hiện tại, chọn tuần và ngày; xem slot/phòng/lớp, vào điểm danh hoặc đổi lịch | GET /semesters, GET /schedule |
| Điểm danh | Radio Absent/Present, ô note, toàn bộ roster, lưu có version | GET/PUT /sessions/:id/attendance |
| Đơn nghỉ | Lọc trạng thái, phân trang, xem lý do và duyệt/từ chối kèm phản hồi | GET /leave-requests, PATCH /leave-requests/:id/decision |
| Đổi lịch/phòng | Chọn buổi tương lai, ngày trong học kỳ, slot, phòng và lý do | GET /rooms, POST /change-requests |
| Yêu cầu đã gửi | Trạng thái duyệt, lịch/phòng cũ và đề xuất, ý kiến cán bộ | GET /change-requests |
| Hồ sơ | Avatar chữ, tên, vai trò, mã tài khoản và email chỉ đọc cho mọi role | GET /profile |

Giao diện giảng viên không có thanh điều hướng dưới. Mở hồ sơ bằng icon tài khoản hoặc mục Hồ sơ của tôi; mở nghiệp vụ từ các thẻ chức năng và mục Yêu cầu đã gửi. Màn con có nút quay lại. Hồ sơ dùng chung chỉ có avatar chữ, tên, vai trò, mã tài khoản, email và ngành học riêng cho sinh viên; không hiển thị bộ môn hoặc thông tin liên hệ.

## Quy tắc tương tác

- Ngày và truy vấn lịch dùng UTC+7, không phụ thuộc múi giờ Windows/browser. Giữ 4 slot cố định 07:30–09:50, 10:00–12:20, 12:50–15:10, 15:20–17:40.
- Roster chỉ lấy từ API, không mặc định sinh viên Có mặt; radio chỉ chọn Absent/Present và ô note hiển thị Đã duyệt đơn nghỉ. LATE/EXCUSED cũ được giữ và hiển thị ở note đến khi chọn lại; phải chọn đủ trạng thái trước khi lưu. Buổi tương lai/hủy chỉ xem. Đơn nghỉ đã duyệt chỉ thêm ghi chú, không tự đổi trạng thái điểm danh.
- Lưu điểm danh gửi đủ lớp và version. Nếu dữ liệu xung đột, giữ bản đang sửa để người dùng xem, yêu cầu tải lại; không tự ghi đè. Khi tải lại hoặc rời màn với thay đổi chưa lưu, có xác nhận bỏ thay đổi.
- Duyệt đơn gửi version và phản hồi bắt buộc; khóa thao tác trong lúc gửi. Khi thất bại, đóng hộp thoại/tải lại trước khi duyệt tiếp để tránh dùng đơn cũ.
- Đổi phòng có thể giữ ngày/slot hiện tại; đổi lịch có thể giữ phòng. Chặn đề xuất không thay đổi. Backend vẫn kiểm tra xung đột, thời gian và quyền; gửi đơn không tự sửa lịch.
- Khi tạo đơn từ trang chủ, danh sách gồm buổi phù hợp trong 92 ngày tới. Buổi xa hơn trong kỳ hiện tại mở từ Lịch dạy theo tuần.
- Đơn phân trang 50 dòng. Lịch trống và lỗi tải có trạng thái riêng/thử lại; tải tuần nhanh có kiểm soát phản hồi cũ.

## Chuỗi mã nguồn

`RoleHomeRouter` → `lecturer/screens/*` → `LecturerRepository` → `ApiClient` → Express route/controller/service/repository → MongoDB.

Các lớp dữ liệu tại `lecturer/models/lecturer_data.dart`, ngày lịch tại `lecturer/utils/lecturer_dates.dart`, style/thẻ dùng chung tại `lecturer/widgets/`.

Backend cấp quyền giảng viên theo lecturer_id của từng buổi, không theo lecturer_id cũ của lớp. Đổi phân công không thay giảng viên trên buổi quá khứ. Danh sách đơn chỉ bổ sung requester (name/user_code), lesson (lớp/môn/ngày/slot/phòng) và original_room_name/proposed_room_name sau khi lọc phạm vi, truy vấn theo lô. Không trả profile đầy đủ của sinh viên hoặc password hash. Lịch bổ sung course_code; các trường cũ giữ nguyên.

## Chạy và xác minh

Giữ backend đang chạy; từ mobile:

```powershell
flutter run -d chrome --web-hostname=localhost --web-port=5173
# Hoặc Windows đã cấu hình bộ build:
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api
```

Đăng nhập `lecturer@myfap.local`, mật khẩu demo `Demo@12345678`. Không seed lại DB đang dùng. Lịch và đơn hiển thị theo dữ liệu thật của database hiện tại; chưa có đơn thì giao diện trống, không bịa bản tin hay sinh viên.

```powershell
flutter analyze
flutter test
flutter build web
```

`test/lecturer_test.dart` dùng fixture API, có kiểm tra điều hướng/profile, lịch, payload/version, đủ roster, future readonly, conflict/bỏ thay đổi, duyệt nghỉ, đổi phòng, retry, layout 320/1100 px với chữ lớn. Có thể render ảnh với font thật bằng PROFILE_FONT_ROOT và LECTURER_PREVIEW_DIR. Đây là widget/fixture test, không phải kiểm thử trên Android/Windows thật.

Backend: `npm test` và `npm run test:workflow` trên database riêng kết thúc `_test` theo README. Workflow xác minh thêm tên người gửi/lớp/phòng, không lộ bí mật và giữ các kiểm tra quyền, đồng thời, lịch sử trước đây.
