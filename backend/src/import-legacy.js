import { readFile } from "node:fs/promises";
import { connect, initialize, disconnect } from "./db.js";
import { importSnapshot } from "./importer.js";
const path = process.argv[2];
if (!path)
  throw new Error(
    "Cách dùng: npm run import:legacy -- path/to/mysql-source.json",
  );
try {
  const snapshot = JSON.parse(await readFile(path, "utf8"));
  await connect();
  await initialize();
  console.log(JSON.stringify(await importSnapshot(snapshot), null, 2));
} finally {
  await disconnect();
}
