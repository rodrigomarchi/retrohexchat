/**
 * @section SP - Virtual Spaces
 * @flow SP1 [done] Choosing a class enters the channel space with that avatar rendered
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";

// A compact signature of the canvas pixels — changes when the world redraws.
async function canvasSignature(page: Page): Promise<number> {
  return page
    .locator('[data-testid="channel-space-shell"] canvas')
    .evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext("2d");
      if (!ctx || !el.width || !el.height) return 0;
      const { data } = ctx.getImageData(0, 0, el.width, el.height);
      let sum = 0;
      for (let i = 0; i < data.length; i += 997)
        sum = (sum + data[i]) % 1_000_000;
      return sum;
    });
}

test.describe("Virtual space character picker", () => {
  test("choosing a class enters the channel space with that avatar rendered", async ({
    browser,
  }) => {
    const user: TestUser = await newSignedInUser(browser, "char");
    try {
      const page = user.page;
      const channel = uniqueChannel("char");
      await user.chat.sendMessage(`/join ${channel}`);

      // Switch the channel view from Chat to Space.
      await page
        .locator(
          '[data-testid="conversation-toolbar"] [data-testid="channel-view-switcher"] button[phx-value-view="space"]',
        )
        .click();

      // The character picker gates the canvas; it shows before the world mounts.
      const picker = page.getByTestId("space-character-select");
      await expect(picker).toBeVisible();
      await expect(page.getByTestId("channel-space-shell")).toHaveCount(0);
      await expect(page.getByTestId("space-avatar-knight")).toBeVisible();
      await expect(page.getByTestId("space-avatar-monk")).toBeVisible();
      await page.screenshot({ path: "test-results/space-picker.png" });

      // Pick the Monk (the 8th character) — the canvas mounts carrying its id.
      await page.getByTestId("space-avatar-monk").click();

      const shell = page.locator(
        '[data-testid="channel-space-shell"][data-avatar="monk"]',
      );
      await expect(shell).toBeVisible();
      await expect(
        page.locator('[data-testid="channel-space-shell"] canvas'),
      ).toBeVisible();

      // The world draws something (avatar + map) onto the canvas.
      await expect
        .poll(() => canvasSignature(page), { timeout: 10_000 })
        .toBeGreaterThan(0);

      await page.screenshot({ path: "test-results/space-monk.png" });

      // Trigger the attack (Space) — exercises the sword action path for a
      // class avatar (its own attack block). The world must keep rendering.
      const canvas = page.locator('[data-testid="channel-space-shell"] canvas');
      await canvas.click();
      await page.keyboard.press("Space");
      await page.screenshot({ path: "test-results/space-monk-attack.png" });
      await expect.poll(() => canvasSignature(page)).toBeGreaterThan(0);
    } finally {
      await closeUsers([user]);
    }
  });
});
