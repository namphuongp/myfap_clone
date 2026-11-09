import { connect, initialize, disconnect } from "./db.js";
import { normalizeLegacySessions } from "./legacy-repair.js";
try {
  await connect();
  await initialize();
  const apply = process.argv.includes("--apply");
  console.log(
    JSON.stringify(
      {
        mode: apply ? "APPLIED" : "PREVIEW_NO_CHANGES",
        sessions: await normalizeLegacySessions({ apply }),
      },
      null,
      2,
    ),
  );
} finally {
  await disconnect();
}
