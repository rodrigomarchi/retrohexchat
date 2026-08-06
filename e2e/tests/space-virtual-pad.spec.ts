/**
 * @section SP - Virtual Spaces
 * @flow SP4 [done] Holding the virtual pad walks continuously and the sword button attacks
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Locator, WebSocket } from "@playwright/test";
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

// The on-screen pad drives the same paced movement as the physical keyboard:
// press-and-hold walks continuously, release stops, the sword button attacks.
test.describe("Space virtual pad", () => {
  test("holding the pad walks continuously and the sword button attacks", async ({
    browser,
  }) => {
    const user: TestUser = await newSignedInUser(browser, "vpad");
    try {
      const channel = uniqueChannel("vpad");
      await user.chat.sendMessage(`/join ${channel}`);

      const page = user.page;
      const sentFrames: string[] = [];
      page.on("websocket", (ws: WebSocket) => {
        ws.on("framesent", (frame) => {
          const payload =
            typeof frame.payload === "string" ? frame.payload : "";
          if (
            payload.includes("space_input") ||
            payload.includes("space_action")
          ) {
            sentFrames.push(payload);
          }
        });
      });

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

      const pad = page.getByTestId("space-virtual-pad");
      await expect(pad).toBeVisible();

      // Press-and-hold the D-pad up button for ~1.2s: at the 150ms server
      // cadence that is a continuous stream of steps, not a single one.
      const up = pad.locator('[data-space-pad-dir="up"]');
      const upBox = (await up.boundingBox())!;
      await page.mouse.move(
        upBox.x + upBox.width / 2,
        upBox.y + upBox.height / 2,
      );
      await page.mouse.down();
      await page.waitForTimeout(1200);
      await page.mouse.up();

      const walked = sentFrames.filter((f) => f.includes("space_input")).length;
      expect(walked).toBeGreaterThanOrEqual(4);
      expect(walked).toBeLessThanOrEqual(12);

      // Releasing stops the walk.
      await page.waitForTimeout(600);
      expect(sentFrames.filter((f) => f.includes("space_input")).length).toBe(
        walked,
      );

      // The sword button broadcasts one visual attack.
      await pad.locator('[data-space-pad-action="attack"]').click();
      await expect
        .poll(() => sentFrames.filter((f) => f.includes("space_action")).length)
        .toBeGreaterThanOrEqual(1);
    } finally {
      await closeUsers([user]);
    }
  });
});
