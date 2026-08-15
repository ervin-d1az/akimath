import { createHttpServer } from "./adapters/http-server.js";

const port = Number(process.env["PORT"] ?? 3000);
const version = process.env["APP_VERSION"] ?? "0.1.0";

createHttpServer(version).listen(port, () => {
  console.log(`ambysmath-api listening on http://localhost:${port}`);
});
