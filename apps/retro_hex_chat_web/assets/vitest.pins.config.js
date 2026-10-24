import { defineConfig } from "vitest/config";

import base from "./vitest.config.js";

// The games' characterization pins: each plays minutes of every game to prove
// a refactor changed nothing a player could see or hear. Too slow for every
// `make ci`, so they run by hand: `make test.js.pins`.
export default defineConfig({
  ...base,
  test: {
    ...base.test,
    include: ["test/lib/games/pins/**/*.test.js"],
    exclude: ["**/node_modules/**"],
  },
});
