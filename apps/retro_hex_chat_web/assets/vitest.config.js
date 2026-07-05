import { fileURLToPath } from "node:url";

import { defineConfig } from "vitest/config";

// esbuild resolves `phoenix` via NODE_PATH=deps at build time; mirror that for
// vitest so hooks that import the Phoenix Socket can be unit-tested.
const phoenixEntry = fileURLToPath(
  new URL("../../../deps/phoenix/priv/static/phoenix.mjs", import.meta.url),
);

export default defineConfig({
  resolve: {
    alias: {
      phoenix: phoenixEntry,
    },
  },
  test: {
    environment: "jsdom",
    include: ["test/**/*.test.js"],
    globals: true,
  },
});
