import { connect, initialize, disconnect } from "../config/database.js";
import { seed } from "../services/seed.service.js";
try {
  await connect();
  await initialize();
  await seed();
  console.log("Đã tạo tài khoản và lịch demo");
} finally {
  await disconnect();
}
