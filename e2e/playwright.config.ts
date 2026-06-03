import { defineConfig, devices } from '@playwright/test';

// Local-only regression suite. Server runs at MIX_ENV=e2e on port 4003 with
// a dedicated retro_hex_chat_e2e database (see config/e2e.exs).
export default defineConfig({
  testDir: './tests',
  globalSetup: './global-setup.ts',
  // Start simple: serial runs share one server. We can flip to parallel once
  // specs prove they tolerate it (will likely need /test/reset by then).
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: 'http://localhost:4003',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Set SLOW_MO=300 (ms) when running headed to watch the spec unfold.
        launchOptions: {
          slowMo: Number(process.env.SLOW_MO) || 0,
        },
      },
    },
  ],
  // Boots `MIX_ENV=e2e mix phx.server` from the repo root if not already up.
  // First compile can be slow; subsequent runs reuse the running server.
  webServer: {
    command: 'cd .. && MIX_ENV=e2e mix phx.server',
    url: 'http://localhost:4003/api/healthz',
    reuseExistingServer: true,
    timeout: 180_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
