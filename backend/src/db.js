import knex from "knex";
export const db = knex({
  client: "mysql2",
  connection: {
    host: process.env.DB_HOST ?? "127.0.0.1",
    port: Number(process.env.DB_PORT ?? 3307),
    user: process.env.DB_USER ?? "myfap",
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME ?? "myfap",
    timezone: "Z",
  },
  pool: {
    min: 0,
    max: 10,
    afterCreate(connection, done) {
      connection.query("SET time_zone = '+00:00'", (error) =>
        done(error, connection),
      );
    },
  },
  acquireConnectionTimeout: 10000,
});
