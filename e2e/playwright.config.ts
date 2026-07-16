import { defineConfig, devices } from "@playwright/test";

const e2ePort = process.env.E2E_PORT || "4003";
const pgPort = process.env.PGPORT || process.env.TEST_DB_PORT || "5433";
const baseURL = process.env.E2E_BASE_URL || `http://localhost:${e2ePort}`;

// Local-only regression suite. Server runs at MIX_ENV=e2e on E2E_PORT with
// a dedicated retro_hex_chat_e2e database (see config/e2e.exs).
export default defineConfig({
  testDir: "./tests",
  globalSetup: "./global-setup.ts",
  // Start simple: serial runs share one server. We can flip to parallel once
  // specs prove they tolerate it (will likely need /test/reset by then).
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  // One retry: these are real-time WebRTC specs whose media plane (RTP flow,
  // renegotiation glare recovery) is inherently non-deterministic under load. A
  // retry only rescues genuine flakes — a deterministic break fails both attempts
  // and stays red, and Playwright reports the retried run as "flaky".
  retries: 1,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
  },
  projects: [
    {
      name: "chromium",
      testIgnore: /.*mobile.*\.spec\.ts/,
      use: {
        ...devices["Desktop Chrome"],
        // Set SLOW_MO=300 (ms) when running headed to watch the spec unfold.
        launchOptions: {
          slowMo: Number(process.env.SLOW_MO) || 0,
        },
      },
    },
    {
      name: "mobile-chrome",
      testMatch: /.*mobile.*\.spec\.ts/,
      use: {
        ...devices["Pixel 5"],
        launchOptions: {
          slowMo: Number(process.env.SLOW_MO) || 0,
        },
      },
    },
  ],
  // Boots `MIX_ENV=e2e mix phx.server` from the repo root if not already up.
  // First compile can be slow; subsequent runs reuse the running server.
  webServer: {
    command: `cd .. && MIX_ENV=e2e E2E_PORT=${e2ePort} PGPORT=${pgPort} mix phx.server`,
    url: `${baseURL}/api/healthz`,
    reuseExistingServer: true,
    timeout: 180_000,
    stdout: "pipe",
    stderr: "pipe",
  },
});
