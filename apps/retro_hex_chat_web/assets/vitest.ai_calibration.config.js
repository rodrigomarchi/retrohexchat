import { defineConfig } from "vitest/config";

import base from "./vitest.config.js";

// The games' AI calibration: each plays hundreds of seeded matches per
// difficulty against a scripted player and checks how often the AI wins.
// Too slow for every `make ci`, and only worth running while tuning an AI,
// so it runs by hand: `make games.ai.calibrate [GAME=pong]`.
export default defineConfig({
  ...base,
  test: {
    ...base.test,
    environment: "node",
    include: ["test/lib/games/calibration/**/*.test.js"],
    exclude: ["**/node_modules/**"],
    testTimeout: 600_000,
  },
});
