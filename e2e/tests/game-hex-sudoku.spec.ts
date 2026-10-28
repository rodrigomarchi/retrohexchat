/**
 * @section N - P2P, File, Call, Game
 * @flow N87 [done] Hex Sudoku on the desktop: opened from the Retro Games folder, the grid is made, a click chooses a square, the arrows move it, H gives a hint, N turns the pencil on, ended with End from the menu and written down
 * @flow N88 [done] Hex Sudoku on a phone: the keypad stands under the grid and fits the screen, a tap chooses a square, the pencil switches on, the lamp gives a hint, and the page does not scroll
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

// Lying down (640×480): 40-pixel squares from (24, 82), the pencil at (514, 350), 48 pixels.
// Standing up (448×632): 48-pixel squares from (8, 52); the pencil at (236, 558) and the lamp
// at (320, 558), 60 pixels.
const SQUARE_LANDSCAPE = (col: number, row: number) => ({
  x: 24 + col * 40 + 20,
  y: 82 + row * 40 + 20,
});
const SQUARE = (col: number, row: number) => ({
  x: 8 + col * 48 + 24,
  y: 52 + row * 48 + 24,
});
const PENCIL = { x: 236 + 30, y: 558 + 30 };
const LAMP = { x: 320 + 30, y: 558 + 30 };

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

/** Each step's picture differs from the one before it. */
async function changes(canvas: Locator, act: () => Promise<void>) {
  const before = await pixels(canvas);
  await act();
  await expect.poll(() => pixels(canvas)).not.toBe(before);
}

async function startAndWaitForTheGrid(game: Page): Promise<Locator> {
  await game.getByTestId("retro-game-start-ai").click();
  await expect(game.getByTestId("game-stage-menu-key")).toBeVisible();
  // The grid is made within a second; the server writes down only a match of
  // three seconds or more, so the test plays as long as a person would.
  await game.waitForTimeout(3000);
  return game.getByTestId("retro-game-canvas-hex_sudoku").locator("canvas");
}

test.describe("Hex Sudoku", () => {
  test("is played with the mouse and the keyboard, and its game written down", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "sudoku");
    try {
      const game = await user.chat.openGameFromFolder("hex_sudoku");
      await waitForView(game);
      const canvas = await startAndWaitForTheGrid(game);
      expect(await viewOf(canvas)).toEqual({ width: 640, height: 480 });
      await shot(canvas, "hex-sudoku-ready");

      // A click chooses a square: its row, column and box light up.
      const square = await pagePoint(canvas, SQUARE_LANDSCAPE(4, 4));
      await changes(canvas, () => game.mouse.click(square.x, square.y));
      // The arrows move the choice; H reveals a square, N turns the pencil on.
      await changes(canvas, () => game.keyboard.press("ArrowRight"));
      await changes(canvas, () => game.keyboard.press("h"));
      await changes(canvas, () => game.keyboard.press("n"));
      await shot(canvas, "hex-sudoku-played");

      // End is in the menu, over the match it holds.

      await game.getByTestId("game-stage-menu-key").click();

      await game.getByTestId("retro-game-end-match").click();
      const result = game.getByTestId("retro-game-result");
      await expect(result.getByTestId("retro-game-ended-early")).toBeVisible();
      await expect(result.getByTestId("retro-game-recorded")).toBeVisible();
      await shot(result, "hex-sudoku-result");
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
        await connect.enterNickname(uniqueNickname("sdph"));
        await connect.registerWithPassword("pass12345");
        await new ChatPage(page).waitUntilConnected();

        await page.goto("/play/hex_sudoku");
        await waitForView(page);
        const canvas = await startAndWaitForTheGrid(page);
        // The keypad stands under the grid on a phone held upright.
        expect(await viewOf(canvas)).toEqual({ width: 448, height: 632 });
        await expect(canvas).toBeInViewport({ ratio: 1 });
        await shot(page, "hex-sudoku-phone");

        const scrolled = await page.evaluate(() => window.scrollY);
        const tap = async (point: { x: number; y: number }) => {
          const at = await pagePoint(canvas, point);
          await page.touchscreen.tap(at.x, at.y);
        };
        await changes(canvas, () => tap(SQUARE(0, 8)));
        await changes(canvas, () => tap(PENCIL));
        // A hint reveals a square and counts on the bar.
        await changes(canvas, () => tap(LAMP));
        expect(await page.evaluate(() => window.scrollY)).toBe(scrolled);
        await shot(canvas, "hex-sudoku-phone-hinted");
      } finally {
        await ctx.close();
      }
    });
  });
});
