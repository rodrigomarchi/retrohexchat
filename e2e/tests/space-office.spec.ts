import { test, expect, type Page } from "@playwright/test";
import { newP2PUser, closeP2PUsers } from "../helpers/p2pFlows";

// Phase 4 acceptance: the "living office" — a chat message paints a speech
// bubble, and walking up to a board and pressing E opens its modal (Escape
// closes it).

async function canvasSignature(page: Page): Promise<number> {
  return page.locator("#space-canvas").evaluate((el: HTMLCanvasElement) => {
    const ctx = el.getContext("2d");
    if (!ctx || el.width === 0) return -1;
    const { data } = ctx.getImageData(0, 0, el.width, el.height);
    let sig = 0;
    for (let i = 0; i < data.length; i += 4) sig = (sig + data[i] * (i + 1)) % 2_147_483_647;
    return sig;
  });
}

test.describe("Virtual space office", () => {
  test("chat paints a bubble and a board opens a modal", async ({ browser }) => {
    const user = await newP2PUser(browser, "off");
    const channel = `#off-${Date.now().toString(36)}`;

    try {
      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);
      await user.chat.sendMessage("/space Office Test");

      const link = user.page.locator('a[href*="/space/"]').first();
      await expect(link).toBeVisible({ timeout: 10_000 });
      await user.page.goto((await link.getAttribute("href")) as string);

      await expect(user.page.getByTestId("space-shell")).toBeVisible({ timeout: 15_000 });
      await expect(user.page.locator("#space-canvas")).toBeVisible();
      await user.page.waitForTimeout(500);

      // Chat: typing a message and pressing Enter paints a speech bubble.
      const before = await canvasSignature(user.page);
      const input = user.page.locator("[data-space-chat-input]");
      await input.click();
      await input.fill("hello office");
      await input.press("Enter");

      await expect(async () => {
        expect(await canvasSignature(user.page)).not.toBe(before);
      }).toPass({ timeout: 10_000 });

      // Walk to (12,11) facing up: the menu board is the faced tile (12,10).
      // Spawn is ~(10,12): right, right, up.
      await user.page.locator("#space-canvas").click();
      await user.page.keyboard.press("ArrowRight");
      await user.page.waitForTimeout(250);
      await user.page.keyboard.press("ArrowRight");
      await user.page.waitForTimeout(250);
      await user.page.keyboard.press("ArrowUp");
      await user.page.waitForTimeout(250);

      await user.page.keyboard.press("e");

      const modal = user.page.locator("[data-space-modal]");
      await expect(modal).toBeVisible({ timeout: 10_000 });
      await expect(modal).toContainText("Tavern menu");

      // Escape closes it.
      await user.page.keyboard.press("Escape");
      await expect(modal).toBeHidden();
    } finally {
      await closeP2PUsers([user]);
    }
  });
});
