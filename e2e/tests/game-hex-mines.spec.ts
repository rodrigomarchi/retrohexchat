/**
 * @section N - P2P, File, Call, Game
 * @flow N85 [done] Hex Mines on the desktop: opened from the Retro Games folder, a click opens the field, a right click plants a flag, ended with End and written down
 * @flow N86 [done] Hex Mines on a phone: the board stands up and fits the screen, a tap opens it, and the switch turns a tap into a flag
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

// The beginner board: lying down (640×480) 40-pixel squares from (140, 82);
// standing up (464×760) 48-pixel squares from (16, 186), the switch at (262, 4).
const SQUARE_LANDSCAPE = (col: number, row: number) => ({
  x: 140 + col * 40 + 20,
  y: 82 + row * 40 + 20,
});
const SQUARE = (col: number, row: number) => ({
  x: 16 + col * 48 + 24,
  y: 186 + row * 48 + 24,
});
const SWITCH = { x: 262 + 18, y: 4 + 18 };

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
  // The board is ready at once; the server writes down only a match of three
  // seconds or more, so the test plays as long as a person would.
  await game.waitForTimeout(3000);
  return game.getByTestId("retro-game-canvas-hex_mines").locator("canvas");
}

test.describe("Hex Mines", () => {
  test("is played with the mouse and its game written down", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "mines");
    try {
      const game = await user.chat.openGameFromFolder("hex_mines");
      await waitForView(game);
      const canvas = await startAndWaitForTheDeal(game);
      await shot(canvas, "hex-mines-ready");

      const before = await pixels(canvas);
      expect(await viewOf(canvas)).toEqual({ width: 640, height: 480 });
      // A right click plants a flag, and the browser's menu stays shut.
      const corner = await pagePoint(canvas, SQUARE_LANDSCAPE(0, 0));
      await game.mouse.click(corner.x, corner.y, { button: "right" });
      await game.waitForTimeout(300);
      expect(await pixels(canvas)).not.toBe(before);

      // A click opens the field.
      const flagged = await pixels(canvas);
      const middle = await pagePoint(canvas, SQUARE_LANDSCAPE(4, 4));
      await game.mouse.click(middle.x, middle.y);
      await game.waitForTimeout(600);
      expect(await pixels(canvas)).not.toBe(flagged);
      await shot(canvas, "hex-mines-opened");

      await game.getByTestId("retro-game-end-match").click();
      const result = game.getByTestId("retro-game-result");
      await expect(result.getByTestId("retro-game-ended-early")).toBeVisible();
      await expect(result.getByTestId("retro-game-recorded")).toBeVisible();
      await shot(result, "hex-mines-result");
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
        await connect.enterNickname(uniqueNickname("mnph"));
        await connect.registerWithPassword("pass12345");
        await new ChatPage(page).waitUntilConnected();

        await page.goto("/play/hex_mines");
        await waitForView(page);
        const canvas = await startAndWaitForTheDeal(page);
        // The board stands up on a phone held upright.
        expect(await viewOf(canvas)).toEqual({ width: 464, height: 760 });
        await expect(canvas).toBeInViewport({ ratio: 1 });
        await shot(page, "hex-mines-phone");

        const before = await pixels(canvas);
        const scrolled = await page.evaluate(() => window.scrollY);
        // The switch, then a tap: a flag.
        const toggle = await pagePoint(canvas, SWITCH);
        await page.touchscreen.tap(toggle.x, toggle.y);
        await page.waitForTimeout(300);
        const switched = await pixels(canvas);
        const corner = await pagePoint(canvas, SQUARE(0, 0));
        await page.touchscreen.tap(corner.x, corner.y);
        await page.waitForTimeout(300);
        expect(await pixels(canvas)).not.toBe(switched);

        // Back to digging: a tap opens the field.
        await page.touchscreen.tap(toggle.x, toggle.y);
        await page.waitForTimeout(300);
        const flagged = await pixels(canvas);
        const middle = await pagePoint(canvas, SQUARE(4, 4));
        await page.touchscreen.tap(middle.x, middle.y);
        await page.waitForTimeout(600);
        expect(await pixels(canvas)).not.toBe(flagged);
        expect(await page.evaluate(() => window.scrollY)).toBe(scrolled);
        await shot(canvas, "hex-mines-phone-flagged");
      } finally {
        await ctx.close();
      }
    });
  });
});
