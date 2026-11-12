import { connect, initialize, disconnect } from "../config/database.js";
import { normalizeLegacySessions } from "../tools/services/legacy-repair.service.js";
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
