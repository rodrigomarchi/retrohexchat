import { test, expect, Locator } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";

// A compact hash of the canvas pixels — changes when anything redraws.
function canvasSignature(canvas: Locator): Promise<number> {
  return canvas.evaluate((el: HTMLCanvasElement) => {
    const ctx = el.getContext("2d");
    if (!ctx || !el.width || !el.height) return 0;
    const { data } = ctx.getImageData(0, 0, el.width, el.height);
    let sum = 0;
    for (let i = 0; i < data.length; i += 97)
      sum = (sum + data[i] * ((i % 251) + 1)) % 1_000_003;
    return sum;
  });
}

// The translucent top-right button presents the space shell fullscreen; the
// same button (in exit state) returns to the normal layout.
test.describe("Space fullscreen toggle", () => {
  test("the toggle enters and exits fullscreen on the space shell", async ({
    browser,
  }) => {
    const user: TestUser = await newSignedInUser(browser, "fsc");
    try {
      const channel = uniqueChannel("fsc");
      await user.chat.sendMessage(`/join ${channel}`);

      const page = user.page;
      const spaceTab = page.locator(
        '[data-testid="conversation-toolbar"] [data-testid="channel-view-switcher"] button[phx-value-view="space"]',
      );
      await expect(spaceTab).toBeVisible();
      await spaceTab.click();

      await expect(page.getByTestId("space-character-select")).toBeVisible();
      await page.getByTestId("space-avatar-knight").click();

      const canvas = page.locator('[data-testid="channel-space-shell"] canvas');
      await expect(canvas).toBeVisible();
      await expect
        .poll(() => canvasSignature(canvas), { timeout: 10_000 })
        .toBeGreaterThan(0);

      const toggle = page.getByTestId("space-fullscreen-toggle");
      await expect(toggle).toBeVisible();

      const fullscreenShell = () =>
        page.evaluate(
          () => document.fullscreenElement?.getAttribute("data-testid") ?? null,
        );

      await toggle.click();
      await expect.poll(fullscreenShell).toBe("channel-space-shell");
      await expect(toggle).toHaveAttribute("data-fullscreen", "");

      // The same button returns to the normal layout.
      await toggle.click();
      await expect.poll(fullscreenShell).toBe(null);
      await expect(toggle).not.toHaveAttribute("data-fullscreen", "");
    } finally {
      await closeUsers([user]);
    }
  });
});
