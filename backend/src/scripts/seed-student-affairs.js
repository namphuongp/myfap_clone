import { connect, initialize, disconnect } from "../config/database.js";
import { seedStudentAffairsDemo } from "../services/student-affairs-demo.service.js";
try {
  await connect();
  await initialize();
  console.log(JSON.stringify(await seedStudentAffairsDemo(), null, 2));
} finally {
  await disconnect();
}
