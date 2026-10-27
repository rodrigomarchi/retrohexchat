/**
 * @section N - P2P, File, Call, Game
 * @flow N81 [done] Hex FreeCell on the desktop: opened from the Retro Games folder, played with the mouse (a click on a column's foot moves its card), ended with End and written down
 * @flow N82 [done] Hex FreeCell on a phone: the table stands up with the mini cards, fits the screen, and a tap moves a card
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { devices, expect, Locator, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import { e2eBaseURL } from "../helpers/env";
import { shot } from "../helpers/screenshots";
import { waitForView } from "../helpers/liveView";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

// The foot of the last column as dealt (six cards), on either table: lying
// down (640×480, full cards) on a desktop, standing up (464×760, minis) on a
// phone held upright.
const FOOT_LANDSCAPE = { x: 29 + 7 * 74 + 20, y: 132 + 5 * 18 + 40 };
const FOOT = { x: 14 + 7 * 56 + 20, y: 104 + 5 * 24 + 30 };

/** The picture the game draws: its canvas has twice its pixels. */
const viewOf = (canvas: Locator) =>
  canvas.evaluate((c: HTMLCanvasElement) => ({
    width: c.width / 2,
    height: c.height / 2,
  }));

/** Where a point of the table is on the page, fitted into its canvas and centred. */
async function pagePoint(canvas: Locator, point: { x: number; y: number }) {
  const box = await canvas.boundingBox();
  if (!box) throw new Error("the canvas has no box");
  const view = await viewOf(canvas);
  const scale = Math.min(box.width / view.width, box.height / view.height);
  return {
    x: box.x + (box.width - view.width * scale) / 2 + point.x * scale,
    y: box.y + (box.height - view.height * scale) / 2 + point.y * scale,
  };
}

const pixels = (canvas: Locator) =>
  canvas.evaluate((c: HTMLCanvasElement) => c.toDataURL("image/png"));

async function startAndWaitForTheDeal(game: Page): Promise<Locator> {
  await game.getByTestId("retro-game-start-ai").click();
  await expect(game.getByTestId("retro-game-end-match")).toBeVisible();
  // The deal flies out, all 52 cards, for about three seconds.
  await game.waitForTimeout(3500);
  return game.getByTestId("retro-game-canvas-hex_freecell").locator("canvas");
}

test.describe("Hex FreeCell", () => {
  test("is played with the mouse and its game written down", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "frcel");
    try {
      const game = await user.chat.openGameFromFolder("hex_freecell");
      await waitForView(game);
      const canvas = await startAndWaitForTheDeal(game);
      await shot(canvas, "hex-freecell-dealt");

      const before = await pixels(canvas);
      expect(await viewOf(canvas)).toEqual({ width: 640, height: 480 });
      const foot = await pagePoint(canvas, FOOT_LANDSCAPE);
      await game.mouse.click(foot.x, foot.y);
      await game.waitForTimeout(600);
      expect(await pixels(canvas)).not.toBe(before);
      await shot(canvas, "hex-freecell-moved");

      await game.getByTestId("retro-game-end-match").click();
      const result = game.getByTestId("retro-game-result");
      await expect(result.getByTestId("retro-game-ended-early")).toBeVisible();
      await expect(result.getByTestId("retro-game-recorded")).toBeVisible();
      await shot(result, "hex-freecell-result");
    } finally {
      await closeUsers([user]);
    }
  });

  test.describe("on a phone", () => {
    const PIXEL_5 = devices["Pixel 5"];
    test("fits the screen and is played by touch", async ({ browser }) => {
      const ctx = await browser.newContext({
        viewport: PIXEL_5.viewport,
        userAgent: PIXEL_5.userAgent,
        deviceScaleFactor: PIXEL_5.deviceScaleFactor,
        isMobile: PIXEL_5.isMobile,
        hasTouch: PIXEL_5.hasTouch,
        baseURL: e2eBaseURL(),
      });
      try {
        const page = await ctx.newPage();
        const connect = new ConnectPage(page);
        await connect.open();
        await connect.enterNickname(uniqueNickname("fcph"));
        await connect.registerWithPassword("pass12345");
        await new ChatPage(page).waitUntilConnected();

        await page.goto("/play/hex_freecell");
        await waitForView(page);
        const canvas = await startAndWaitForTheDeal(page);
        // The table stands up on a phone held upright, dealt in the mini cards.
        expect(await viewOf(canvas)).toEqual({ width: 464, height: 760 });
        await expect(canvas).toBeInViewport({ ratio: 1 });
        await shot(page, "hex-freecell-phone");

        const before = await pixels(canvas);
        const scrolled = await page.evaluate(() => window.scrollY);
        const foot = await pagePoint(canvas, FOOT);
        await page.touchscreen.tap(foot.x, foot.y);
        await page.waitForTimeout(600);
        expect(await pixels(canvas)).not.toBe(before);
        expect(await page.evaluate(() => window.scrollY)).toBe(scrolled);
        await shot(canvas, "hex-freecell-phone-tapped");
      } finally {
        await ctx.close();
      }
    });
  });
});
