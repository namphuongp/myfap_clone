import mongoose from "mongoose";
const uri = process.env.MONGODB_URI;
if (!uri) throw new Error("Thiếu MONGODB_URI");
const parsed = new URL(uri);
const setName = parsed.searchParams.get("replicaSet");
if (!setName) throw new Error("MONGODB_URI cần replicaSet");
parsed.searchParams.delete("replicaSet");
parsed.searchParams.set("directConnection", "true");
const client = new mongoose.mongo.MongoClient(parsed.toString(), {
  serverSelectionTimeoutMS: 10000,
});
try {
  await client.connect();
  const admin = client.db("admin");
  try {
    const status = await admin.command({ replSetGetStatus: 1 });
    if (status.set !== setName)
      throw new Error("Replica set hiện tại khác cấu hình, không tự thay đổi");
  } catch (error) {
    if (error.code !== 94) throw error;
    await admin.command({
      replSetInitiate: {
        _id: setName,
        members: [{ _id: 0, host: parsed.host }],
      },
    });
  }
  for (let i = 0; i < 60; i++) {
    const hello = await admin.command({ hello: 1 });
    if (hello.isWritablePrimary) {
      console.log("Replica set sẵn sàng");
      process.exitCode = 0;
      break;
    }
    if (i === 59) throw new Error("Replica set chưa bầu primary");
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
} finally {
  await client.close();
}
