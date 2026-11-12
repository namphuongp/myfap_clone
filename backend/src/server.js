import { applyDueMajorTransfers } from "./services/major-transfer.service.js";
import { connect, initialize, disconnect } from "./config/database.js";
import { createApp } from "./app.js";
await connect();
await initialize();
await applyDueMajorTransfers();
let applying = false;
const transferTimer = setInterval(async () => {
  if (applying) return;
  applying = true;
  try {
    await applyDueMajorTransfers();
  } catch (error) {
    console.error("Không áp dụng được đơn chuyển ngành:", error.message);
  } finally {
    applying = false;
  }
}, 60000);
transferTimer.unref();
const port = Number(process.env.PORT ?? 3000);
const server = createApp().listen(port, "0.0.0.0", () =>
  console.log(`MyFAP Express/Mongoose: http://localhost:${port}/api`),
);
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => {
    clearInterval(transferTimer);
    server.close(async () => {
      await disconnect();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  });
