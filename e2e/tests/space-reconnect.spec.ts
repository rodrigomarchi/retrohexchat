import { test, expect, type Page } from "@playwright/test";
import { newP2PUser, closeP2PUsers } from "../helpers/p2pFlows";

// Phase 6 acceptance: robustness of reconnect. Reloading the page returns the
// avatar to the tile it left (position survives the round trip), and opening a
// second tab as the same identity takes over the session instead of spawning a
// duplicate participant.

// A compact signature of the canvas drawing buffer; changes when anything on
// the canvas is redrawn to different pixels. Because the atlas and camera are
// deterministic for a fixed position, the same tile renders the same signature.
async function canvasSignature(page: Page): Promise<number> {
  return page.locator("#space-canvas").evaluate((el: HTMLCanvasElement) => {
    const ctx = el.getContext("2d");
    if (!ctx || el.width === 0) return -1;
    const { data } = ctx.getImageData(0, 0, el.width, el.height);
    let sig = 0;
    for (let i = 0; i < data.length; i += 4) {
      sig = (sig + data[i] * (i + 1)) % 2_147_483_647;
    }
    return sig;
  });
}

async function waitForPaint(page: Page) {
  await expect(page.getByTestId("space-shell")).toBeVisible({
    timeout: 15_000,
  });
  await expect(page.locator("#space-canvas")).toBeVisible();
  await expect(async () => {
    expect(await canvasSignature(page)).toBeGreaterThan(0);
  }).toPass({ timeout: 15_000 });
}

test.describe("Virtual space reconnect", () => {
  test("reload returns to the same tile; a second tab takes over", async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, "rca");
    const channel = `#rc-${Date.now().toString(36)}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.sendMessage("/space Reconnect Test");

      const link = alice.page.locator('a[href*="/space/"]').first();
      await expect(link).toBeVisible({ timeout: 10_000 });
      const href = (await link.getAttribute("href")) as string;

      await alice.page.goto(href);
      await waitForPaint(alice.page);

      // Baseline at spawn, then walk right a few tiles.
      await alice.page.waitForTimeout(400);
      const spawnSig = await canvasSignature(alice.page);

      await alice.page.locator("body").click();
      for (let i = 0; i < 3; i += 1) {
        await alice.page.keyboard.press("ArrowRight");
        await alice.page.waitForTimeout(200);
      }

      // The view must actually differ from spawn (she moved).
      await expect(async () => {
        expect(await canvasSignature(alice.page)).not.toBe(spawnSig);
      }).toPass({ timeout: 10_000 });
      await alice.page.waitForTimeout(400);
      const movedSig = await canvasSignature(alice.page);

      // Reload: position is preserved by the takeover, so she lands on the same
      // tile — not back at spawn.
      await alice.page.reload();
      await waitForPaint(alice.page);

      await expect(async () => {
        const sig = await canvasSignature(alice.page);
        expect(sig).not.toBe(spawnSig);
        expect(sig).toBe(movedSig);
      }).toPass({ timeout: 15_000 });

      // Second tab as the same identity takes over: still a single participant,
      // so the HUD count stays at 1 (no duplicate avatar).
      const second = await alice.ctx.newPage();
      await second.goto(href);
      await waitForPaint(second);

      await expect(second.locator("[data-space-hud-count]")).toHaveText("1", {
        timeout: 15_000,
      });

      await second.close();
    } finally {
      await closeP2PUsers([alice]);
    }
  });
});
