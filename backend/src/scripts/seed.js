import { connect, initialize, disconnect } from "../config/database.js";
import { seedAllDemo } from "../services/seed-demo.service.js";
try {
  await connect();
  await initialize();
  console.log(JSON.stringify(await seedAllDemo(), null, 2));
} catch (error) {
  console.error("Không seed được dữ liệu demo:", error.message);
  process.exitCode = 1;
} finally {
  await disconnect();
}
