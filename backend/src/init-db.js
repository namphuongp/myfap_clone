import { connect, initialize, disconnect } from "./db.js";
try {
  await connect();
  await initialize();
  console.log("Đã khởi tạo collection, index và khóa học vụ");
} finally {
  await disconnect();
}
