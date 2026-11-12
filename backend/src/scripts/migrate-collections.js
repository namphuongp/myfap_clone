import net from "node:net";
import { connect, initialize, disconnect } from "../config/database.js";
import { migrateCollections } from "../repositories/collection-migration.repository.js";
const apply = process.argv.includes("--apply");
let guard;
try {
  if (apply) {
    // Giữ cổng API trong lúc chuyển dữ liệu, ngăn backend chạy đồng thời với migration.
    guard = net.createServer();
    await new Promise((resolve, reject) => {
      guard.once("error", reject);
      guard.listen(Number(process.env.PORT ?? 3000), "0.0.0.0", resolve);
    });
  }
  await connect();
  if (apply) await initialize({ allowLegacy: true });
  console.log(JSON.stringify(await migrateCollections({ apply }), null, 2));
} catch (error) {
  console.error(
    "Không chuyển được collection:",
    error.code === "EADDRINUSE"
      ? "Hãy dừng backend trước khi chạy migration"
      : error.message,
  );
  process.exitCode = 1;
} finally {
  await disconnect();
  if (guard?.listening) await new Promise((resolve) => guard.close(resolve));
}
