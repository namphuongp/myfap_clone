import test from "node:test";
import assert from "node:assert/strict";
import { fixture } from "./fixtures.js";
import { disconnect } from "../src/config/database.js";
import { Department } from "../src/models/index.js";
test("HEAD retains scoped read-only reporting after feature removal", async () => {
  let f;
  try {
    assert.match(new URL(process.env.MONGODB_URI).pathname, /_test$/);
    f = await fixture();
    const { as, section, future } = f;
    for (const path of [
      "/department/summary",
      "/reports/attendance",
      "/reports/requests",
      "/head/options",
    ])
      await as("head", "get", path).expect(200);
    for (const [method, path] of [
      ["post", "/courses"],
      ["patch", "/courses/" + f.course._id],
      ["get", "/head/courses"],
      ["post", "/head/courses"],
      ["get", "/head/sections"],
      ["get", "/lecturers"],
      ["put", "/sections/" + section._id + "/assignments"],
    ]) {
      let req = as("head", method, path);
      if (method !== "get") req = req.send({});
      await req.expect(404);
    }
    await as("head", "post", "/change-requests").send({}).expect(403);
    await as("head", "get", "/change-requests").expect(403);
    await as("head", "get", `/sessions/${future._id}/attendance`).expect(403);
    const dept = await Department.create({
      code: "OTHER",
      name: "Other department",
    });
    const other = await f.person("LECTURER", dept._id);
    await as(
      "head",
      "get",
      `/reports/attendance?lecturer_id=${other.row._id}`,
    ).expect(403);
    const options = (await as("head", "get", "/head/options")).body;
    assert.ok(
      options.courses.every(
        (r) => r.department_id === String(f.department._id),
      ),
    );
    assert.equal(options.majors, undefined);
  } finally {
    await disconnect();
  }
});
