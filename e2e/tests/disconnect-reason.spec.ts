/**
 * @section Auth And Lifecycle
 * @flow I [done] `/connect?reason=expired` surfaces session expired message
 * @flow J [done] `/connect?reason=disconnected` surfaces session ended message
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";

test.describe("Disconnect reason banners", () => {
  test('?reason=expired surfaces "Session expired" (I)', async ({ page }) => {
    await page.goto("/connect?reason=expired");
    const banner = page.getByTestId("session-alert");
    await expect(banner).toBeVisible();
    await expect(banner).toContainText("Session expired");
  });

  test('?reason=disconnected surfaces "Session ended" (J)', async ({
    page,
  }) => {
    await page.goto("/connect?reason=disconnected");
    const banner = page.getByTestId("session-alert");
    await expect(banner).toBeVisible();
    await expect(banner).toContainText("Session ended");
  });
});
