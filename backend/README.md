# MyFAP backend

Node.js 22.12+, Express, Mongoose và MongoDB replica set. API hiện tại: [API.md](../API.md). Database gồm 17 collection, chi tiết [database.md](../database.md).

## Chạy dự án

Trong backend: chạy npm ci, tạo .env từ .env.example và khởi động MongoDB replica set. Với DB cũ, dừng backend rồi chạy npm run db:migrate:preview và npm run db:migrate. Sau đó chạy npm run dev. npm run seed bổ sung dữ liệu demo; không dùng seed để thay migration.

## Tổ chức source

```text
src/
  modules/
    auth/       # Đăng nhập và phiên
    student/    # Router thao tác riêng của sinh viên
    lecturer/   # Điểm danh, duyệt nghỉ, gửi đơn đổi lịch/phòng
    head/       # Quản lý giảng viên và báo cáo bộ môn
    staff/      # Thông báo, duyệt đổi lịch/phòng và chuyển ngành
    shared/     # Lịch, hồ sơ, đơn từ và nghiệp vụ dùng chung
  routes/index.js   # Gom các router role, không chứa nghiệp vụ
  models/           # Schema database dùng chung giữa các role
  repositories/     # Truy vấn, transaction và migration
  middlewares/      # Xác thực, phân quyền, validate, xử lý lỗi
  tools/services/   # Seed, import và chuẩn hóa dữ liệu cũ
  scripts/          # Điểm chạy công cụ bằng npm
  config/           # Kết nối database
  utils/            # Ngày, slot, ID và serialize
```

Trong module, controller nhận HTTP, service xử lý nghiệp vụ, validator kiểm tra input. Model/repository không nhân bản theo role. API nhiều role cùng dùng được khai báo tại shared/shared.routes.js; quyền và URL được giữ nguyên. Mỗi hàm có tên có comment tiếng Việt ngắn.

## Phạm vi

- STUDENT: lịch học, gửi/xem đơn nghỉ và chuyển ngành, đọc thông báo.
- LECTURER: lịch dạy, điểm danh trong ngày, duyệt nghỉ, gửi/xem đơn đổi lịch/phòng.
- HEAD: quản lý giảng viên trong bộ môn và báo cáo.
- STAFF: tạo/phát hành thông báo, duyệt đổi lịch/phòng và chuyển ngành.
- Hồ sơ mọi role chỉ đọc, không sửa hoặc đổi mật khẩu. Avatar là chữ đầu tên ở frontend.
- Không còn chức năng tự đăng ký môn/rút lớp. ClassMembership do seed/import thiết lập và giữ lịch sử sinh viên thuộc lớp.
- Chuyển ngành đã duyệt chờ kỳ kế tiếp; đến hạn mới đổi ngành/bộ môn và kết thúc lớp ngoài chương trình ngành mới. Giữ môn chung, lịch sử và điểm danh.

## Kiểm thử

npm test chạy bảo mật; các lệnh test:workflow, test:head, test:lecturers, test:affairs, test:import, test:seed chạy từng nhóm API. Các suite có DB chỉ chấp nhận database kết thúc bằng _test và cần DB test trống. Không chạy suite có ghi dữ liệu trên database demo hoặc dữ liệu thật. Các test migration và chuyển ngành theo kỳ nằm trong test/collection-migration.test.js và test/transfer-membership.test.js.
