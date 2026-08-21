import { availableParallelism } from "node:os";
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
    // `make ci` runs this alongside three Elixir test partitions, four feature
    // partitions and dialyzer. Left to its own devices vitest forks one worker
    // per core into that, and the workers then miss their own startup deadline:
    // "Failed to start forks worker ... Timeout waiting for worker to respond",
    // with no test having run. Standalone the same suite is 4869 green in 13s.
    // A quarter of the cores leaves room for the rest of the pipeline, and the
    // longer deadline covers a fork that is merely slow to be scheduled.
    pool: "forks",
    poolOptions: {
      forks: {
        maxForks: Math.max(2, Math.floor((availableParallelism?.() ?? 4) / 4)),
      },
    },
    teardownTimeout: 30_000,
  },
});
