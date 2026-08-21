import { defineConfig, devices } from "@playwright/test";

// Load-test harness config — intentionally separate from the regression
// suite (playwright.config.ts). It never auto-starts a server: it points at
// an already-running deployment (production by default, override for local).
//
//   LOAD_BASE_URL     target server (default: https://retrohexchat.app)
//   LOAD_USERS        concurrent simulated users (default: 20)
//   LOAD_DURATION_MS  steady-state duration after ramp-up (default: 180000)
//
// Run with: make load.test   (or: cd e2e && npx playwright test --config=load/load.config.ts)
const baseURL = process.env.LOAD_BASE_URL || "https://retrohexchat.app";
const durationMs = Number(process.env.LOAD_DURATION_MS) || 180_000;

export default defineConfig({
  testDir: ".",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  // Ramp-up + steady state + wind-down/report margin. The margin is not slack:
  // 20 users ramping against production take ~3 min of WAN round trips before
  // steady state starts, and tearing down 20 browser contexts afterwards is not
  // instant. A run that reaches steady state and then dies on the clock throws
  // away the whole measurement.
  timeout: durationMs + 480_000,
  // WAN latency + many tabs sharing one generator machine: the default 5s
  // expect timeout is too tight during ramp-up.
  expect: { timeout: 15_000 },
  reporter: [["list"]],
  use: {
    ...devices["Desktop Chrome"],
    baseURL,
    trace: "off",
    screenshot: "off",
    video: "off",
    actionTimeout: 15_000,
    navigationTimeout: 45_000,
  },
});
