import { startMajorTransferJob } from "./jobs/major-transfer.job.js";
import { connect, initialize, disconnect } from "./config/database.js";
import { createApp } from "./app.js";
await connect();
await initialize();
const stopMajorTransferJob = startMajorTransferJob();
const port = Number(process.env.PORT ?? 3000);
const server = createApp().listen(port, "0.0.0.0", () =>
  console.log(`MyFAP Express/Mongoose: http://localhost:${port}/api`),
);
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => {
    stopMajorTransferJob();
    server.close(async () => {
      await disconnect();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  });
