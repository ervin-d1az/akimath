import { startHttpServer } from "./adapters/http-server.js";

const port = Number(process.env["PORT"] ?? 3000);
const version = process.env["APP_VERSION"] ?? "0.1.0";

startHttpServer(version, port);
console.log(`akimath-api listening on http://localhost:${port}`);
