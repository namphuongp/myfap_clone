import { db } from "./db.js";
import { createApp } from "./app.js";
await db.raw("SELECT 1");
const server = createApp().listen(
  Number(process.env.PORT ?? 3000),
  "0.0.0.0",
  () =>
    console.log(`MyFAP API: http://localhost:${process.env.PORT ?? 3000}/api`),
);
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => {
    server.close(async () => {
      await db.destroy();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  });
