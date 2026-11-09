import { connect, initialize, disconnect } from "../config/database.js";
import { bootstrapAcademicCalendar } from "../services/academic-bootstrap.service.js";
try {
  await connect();
  await initialize();
  console.log(
    JSON.stringify(
      {
        mode: process.argv.includes("--apply") ? "APPLIED" : "PREVIEW",
        sections: await bootstrapAcademicCalendar({
          apply: process.argv.includes("--apply"),
        }),
      },
      null,
      2,
    ),
  );
} finally {
  await disconnect();
}
