# MyFAP Flutter và Express Mongoose MongoDB

Dự án tại `D:\Study\Project\myfap_clone`. Frontend Dart/Flutter Android và Web; backend Node.js/Express + Mongoose; MongoDB replica set dùng transaction. Không có chức năng điểm, không kết nối FAP thật.

## Quy tắc đã triển khai

- STUDENT: lịch, đăng ký môn thuộc ngành, đơn nghỉ/chuyển ngành, thông báo. LECTURER: lịch dạy, duyệt nghỉ, yêu cầu đổi lịch/phòng, điểm danh. HEAD: báo cáo bộ môn. STAFF: thông báo, duyệt đổi lịch/chuyển ngành và quản trị dữ liệu vận hành. Mọi role có profile.
- Ngành có chương trình môn riêng và môn chung. Chuyển ngành được duyệt có hiệu lực từ đầu kỳ sau ngày gửi; rút môn chỉ thuộc ngành cũ ở kỳ hiệu lực trở đi, giữ môn chung và lịch sử.
- Năm học bắt đầu Fall (tháng 9–11), Spring (1–3), Summer (5–7); nghỉ tháng 12, 4, 8. API nhận term/year và tự tính mốc UTC+7.
- Một môn có nhiều lớp ở nhiều học kỳ. Mỗi lớp cố định **30 sinh viên**. Cán bộ xếp lịch trước; sinh viên xem lịch/chỗ còn rồi tự đăng ký. STAFF cũng có thể đăng ký/rút thay sinh viên. Không đăng ký hai lớp cùng môn trong cùng kỳ.
- Khi đăng ký kiểm tra chỗ còn, phòng, trùng toàn bộ lịch tương lai; đăng ký tranh chỗ cuối được tuần tự hóa trong transaction. Lớp đầy trả 409 để chọn lớp khác.
- Slot cố định theo giờ Việt Nam UTC+7: **07:30–09:50**, **10:00–12:20**, **12:50–15:10**, **15:20–17:40**. Nghỉ giữa buổi 10 phút, nghỉ trưa 30 phút. Backend nhận ngày + slot, tự tính giờ UTC; không nhận giờ tự do.
- Đơn nghỉ áp dụng đúng buổi của môn, ngày và slot đã gửi. Đổi ngày/giờ làm đơn PENDING/APPROVED thành INVALIDATED; sinh viên gửi đơn mới nếu cần. Chỉ đổi phòng giữ đơn.
- Đơn nghỉ APPROVED hiển thị ghi chú **Nghỉ có phép** cạnh điểm danh, không tự biến thành PRESENT. NOT_RECORDED thể hiện chưa ghi nhận. Giảng viên chọn PRESENT/ABSENT/LATE/EXCUSED.
- Điểm danh chỉ sau khi buổi bắt đầu, phải gửi đủ danh sách của buổi. Khi rút/đăng ký lại lớp, các khoảng đăng ký cũ vẫn giữ; không mất điểm danh quá khứ.
- Buổi học có SCHEDULED/COMPLETED/CANCELLED. Cán bộ chỉ hủy buổi chưa bắt đầu, chưa điểm danh. Hủy buổi giải phóng phòng/slot và hủy đơn còn hiệu lực. Đánh dấu COMPLETED sau giờ kết thúc; dữ liệu demo quá khứ được chuẩn hóa thành COMPLETED.
- Mọi thay đổi học vụ có version, transaction và audit before/after; đổi lịch có lịch sử cũ/mới. Mỗi lần sửa điểm danh giữ snapshot trước và sau.

## Chạy môi trường hiện tại

Máy đã có MongoDB Server; dự án dùng instance riêng cổng **27018**, replica set `myfap-rs`, dữ liệu `.local/mongo-data`. MongoDB 27017 của máy được giữ nguyên. `.local/` và `.env` bị loại khỏi Git.

```powershell
cd D:\Study\Project\myfap_clone
.\start-local.ps1
```

API: `http://localhost:3000/api`; health trả `{"status":"ok","database":"mongodb"}`. Backend/.env trỏ tới `mongodb://127.0.0.1:27018/myfap?replicaSet=myfap-rs`.

Tài khoản demo: `student@myfap.local`, `lecturer@myfap.local`, `head@myfap.local`, `staff@myfap.local`; mật khẩu **Demo@12345678**. Dữ liệu cũ đã được chuyển bằng importer; không chạy seed lại trên database này.

## Máy mới

Cần Node.js >=22.12, Flutter/Android SDK; MongoDB hỗ trợ replica set hoặc MongoDB Atlas. Có thể dùng Docker Compose:

```powershell
cd D:\Study\Project\myfap_clone
docker compose up -d --wait
cd backend
Copy-Item .env.example .env # Chỉ khi chưa có cấu hình riêng
npm ci
npm run db:replica # Chỉ cho MongoDB cục bộ, không chạy với Atlas
npm run db:init
npm run seed # Chỉ database chưa có người dùng
npm run dev
```

Nếu dùng MongoDB Server trên Windows, chạy `start-local.ps1` sau `npm ci`. Script tự tìm mongod trong PATH hoặc `C:\Program Files\MongoDB\Server`; có thể đặt `$env:MONGOD_EXE` nếu cài nơi khác. Nếu dùng Atlas: đổi MONGODB_URI, chạy db:init/seed nếu database trống, rồi npm run dev; không dùng start-local hoặc db:replica.

MongoDB standalone không hỗ trợ transaction của dự án. Local dùng single-node replica set. Compose chỉ bind cổng lên loopback để phục vụ phát triển. Môi trường triển khai phải có tài khoản DB, kết nối bảo mật và HTTPS. Không commit URI có credential.

Trong terminal khác:

```powershell
cd D:\Study\Project\myfap_clone\mobile
flutter pub get
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Máy thật dùng IP LAN của máy chạy API. Chỉ Android debug cho HTTP; release phải dùng HTTPS. Flutter hiện có đăng nhập/đăng xuất, lịch, đăng ký môn cho sinh viên, tổng quan HEAD và profile cho bốn role (avatar chữ, sửa liên hệ, đổi mật khẩu). Giảng viên có bốn màn hình lịch dạy, duyệt đơn nghỉ, yêu cầu đổi lịch/phòng và điểm danh, đã kết nối API. Thông báo và đơn từ phía sinh viên còn cần xây tiếp.

Chạy trên Chrome (không cần Android emulator): mở API bằng `start-local.ps1`, sau đó trong thư mục `mobile` chạy `flutter run -d chrome --web-hostname=localhost --web-port=5173`. Web mặc định gọi `http://localhost:3000/api`; cổng web 5173 được cho phép trong `backend/.env.example`. Xem [mobile/README.md](mobile/README.md) để biết lệnh chạy đầy đủ.

## Chuyển dữ liệu cũ và chuẩn hóa lịch

Backup SQL, snapshot JSON, bản nháp MySQL đều ở `.local/` và không lên Git. Backend hiện tại không có dependency MySQL/Knex. Importer nhận snapshot định dạng `myfap-mysql-v1`, không cần kết nối SQL:

```powershell
cd backend
npm run import:legacy -- ..\.local\backups\mysql-source.json
npm run slots:preview
npm run slots:repair
```

Importer chỉ chạy trên database chưa có người dùng, hoặc trả kết quả đã import nếu cùng source hash. Import nguyên tử, giữ hash mật khẩu, đăng ký, điểm danh và version. ID mới là **ObjectId**, API trả `id`; `legacy_id` giữ số cũ để đối chiếu. Không dùng ID số cũ gọi API.

Buổi cũ lệch giờ được đưa về slot gần giờ bắt đầu cũ nhất trong cùng ngày, có kiểm tra xung đột. Không có slot hợp lệ thì toàn bộ đợt sửa được hoàn tác. Preview chạy thử rồi rollback. Lịch cũ lưu trong SessionHistory; điểm danh vẫn được giữ. Các đơn nghỉ có lịch thay đổi bị INVALIDATED; đơn đổi lịch PENDING bị CANCELLED. Đây là lệnh sửa dữ liệu cũ được kiểm soát, có thể xử lý cả buổi đã kết thúc; API thường vẫn chặn đổi buổi quá khứ.

Importer giữ mã môn LEGACY-n và kỳ LEGACY khi thiếu metadata. Sau import, dùng `npm run academics:preview` rồi `npm run academics:normalize` để ánh xạ lớp vào kỳ chuẩn dựa trên lịch thực; chặn lớp có buổi trong tháng nghỉ hoặc nhiều kỳ. Database demo đã chuẩn hóa FALL-2026. Không dựng lại lịch sử trước khi có snapshot. Đăng ký cũ không có thời gian bắt đầu được gắn mốc 1970 để giữ quyền xem điểm danh quá khứ. Đơn đổi lịch cũ không có bằng chứng lịch gốc thì original_* giữ null.

## Cấu trúc

Backend theo luồng **route → controller → service → repository → model → MongoDB**:

- `backend/src/routes/`: URL, quyền và validator.
- `backend/src/controllers/`: nhận request, gọi service và trả response.
- `backend/src/services/`: nghiệp vụ, kiểm tra quyền theo dữ liệu, transaction và audit.
- `backend/src/repositories/`: truy vấn/lưu MongoDB, repository riêng theo model, CRUD dùng chung.
- `backend/src/models/`: schema và index Mongoose, một file cho mỗi thực thể.
- `backend/src/validators/`, `middlewares/`, `utils/`: kiểm tra đầu vào và phần dùng chung.
- `backend/src/jobs/`: áp dụng chuyển ngành đến hạn, đồng bộ thêm khi xác thực.
- `backend/src/config/`, `scripts/`: kết nối DB, init/seed/import và công cụ dữ liệu.
- [Kiến trúc backend](backend/README.md): trách nhiệm từng lớp và ví dụ luồng đăng ký.
- `mobile/lib/core/profile/screens/profile_screen.dart` → `core/profile/repositories/profile_repository.dart` → `core/api/api_client.dart` → Express API.
- [API.md](API.md), [requests.http](requests.http), [database.md](database.md), [Học vụ và profile](STUDENT_AFFAIRS.md).
Không có API sửa/xóa tài khoản/danh mục hoặc đổi giảng viên của lớp. Thông tin tham chiếu được kiểm tra bởi service; không sửa trực tiếp DB trong lúc ứng dụng đang hoạt động. Khi mở rộng cần tiếp tục giữ các quy tắc này.

## Kiểm thử

```powershell
cd backend
npm test
```

8 bài bảo mật/validation không cần DB. Workflow/import/học vụ test phải dùng các database **riêng, trống**, tên kết thúc bằng `_test`; không chạy trên myfap:

```powershell
$stamp = Get-Date -Format yyyyMMddHHmmss
$env:MONGODB_URI = "mongodb://127.0.0.1:27018/myfap_workflow_${stamp}_test?replicaSet=myfap-rs"
npm run test:workflow
$env:MONGODB_URI = "mongodb://127.0.0.1:27018/myfap_affairs_${stamp}_test?replicaSet=myfap-rs"
npm run test:affairs
$env:MONGODB_URI = "mongodb://127.0.0.1:27018/myfap_import_${stamp}_test?replicaSet=myfap-rs"
npm run test:import
Remove-Item Env:MONGODB_URI
npm run format:check
```

Test không xóa dữ liệu sau khi chạy; dùng tên mới cho mỗi đợt để giữ bằng chứng. Workflow bao gồm tranh chỗ cuối, chống ghi đè điểm danh, đổi slot vô hiệu đơn, giữ lịch sử, phân quyền theo bộ môn và logout. Import test có rollback khi thiếu tham chiếu, giữ hash/version/điểm danh, chạy lại không nhân đôi và preview không ghi dữ liệu.

Tài liệu chính thức: [Mongoose schemas](https://mongoosejs.com/docs/guide.html), [MongoDB replica set](https://www.mongodb.com/docs/manual/tutorial/deploy-replica-set/).

## Xác minh

- MongoDB Server 8.3.x cục bộ, replica set myfap-rs, cổng 27018: đã chạy thật.
- 8/8 kiểm tra bảo mật/validation đạt.
- 9 nhóm workflow (10 test tính cả suite cha) đạt trên database test riêng; có tranh chỗ thứ 30 và ghi điểm danh đồng thời.
- Import/chuẩn hóa lịch cũ: đạt; có test rollback khi snapshot lỗi, giữ password hash/version/điểm danh, preview không ghi dữ liệu và import không nhân đôi.
- Database myfap hiện có 4 tài khoản, 2 phòng, 1 lớp, 1 đăng ký và 2 buổi đã chuyển từ snapshot. Hai buổi cũ ngày 09/11 và 10/11/2026 đã chuẩn hóa về slot 4 (15:20–17:40), có lịch sử giờ cũ/mới.
- Script start-local đã chạy; health xác nhận mongodb, đăng nhập tài khoản cũ và xem lịch/logout trên API cổng 3000 đạt. MySQL portable cổng 13379 đã dừng; dữ liệu/backup còn trong .local.
- Học vụ/profile: 11 test tính cả suite cha đạt trên MongoDB test riêng; Flutter 13 widget test đạt, Dart analyze không có vấn đề. Test mốc chuyển ngành dùng thời gian giả lập trong service, widget dùng API fixture.
- Prettier và git diff --check đạt. Chưa chạy Docker Compose, chưa kiểm thử frontend trên thiết bị/emulator hay build APK trong lần đổi backend này.
