/**
 * @section N - P2P, File, Call, Game
 * @flow N89 [done] Hex Blocks on the desktop: opened from the Retro Games folder, the count runs out, the arrows move the piece and the space bar drops it, ended with End and written down
 * @flow N90 [done] Hex Blocks on a phone: the buttons stand under the well and fit the screen, a tap drops a piece, two fingers hold two buttons at once, and the page does not scroll
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

// Standing up (400×640): the buttons are 60 pixels, the first row at y 486
// (left at x 44, drop at x 296), the second at y 560 (turn clockwise at x 170).
const BUTTON = (x: number, y: number) => ({ x: x + 30, y: y + 30 });
const LEFT = BUTTON(44, 486);
const DROP = BUTTON(296, 486);
const TURN = BUTTON(170, 560);

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

async function startAndWaitForThePiece(game: Page): Promise<Locator> {
  await game.getByTestId("retro-game-start-ai").click();
  await expect(game.getByTestId("retro-game-end-match")).toBeVisible();
  // The count is three seconds; the server writes down only a match of three
  // seconds or more, so the test plays as long as a person would.
  await game.waitForTimeout(3500);
  return game.getByTestId("retro-game-canvas-hex_blocks").locator("canvas");
}

test.describe("Hex Blocks", () => {
  test("is played with the keyboard, and its game written down", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "blocks");
    try {
      const game = await user.chat.openGameFromFolder("hex_blocks");
      await waitForView(game);
      await expect(game.getByTestId("retro-game-start-ai")).toBeInViewport({
        ratio: 1,
      });
      const canvas = await startAndWaitForThePiece(game);
      expect(await viewOf(canvas)).toEqual({ width: 640, height: 480 });
      await shot(game, "hex-blocks-falling");

      await changes(canvas, () => game.keyboard.press("ArrowLeft"));
      await changes(canvas, () => game.keyboard.press("ArrowUp"));
      await changes(canvas, () => game.keyboard.press(" "));
      await changes(canvas, () => game.keyboard.press(" "));
      await shot(canvas, "hex-blocks-dropped");

      await game.getByTestId("retro-game-end-match").click();
      const result = game.getByTestId("retro-game-result");
      await expect(result.getByTestId("retro-game-ended-early")).toBeVisible();
      await expect(result.getByTestId("retro-game-recorded")).toBeVisible();
      await shot(result, "hex-blocks-result");
    } finally {
      await closeUsers([user]);
    }
  });

  test.describe("on a phone", () => {
    const PIXEL_5 = devices["Pixel 5"];
    test("fits the screen and is played with two fingers", async ({
      browser,
    }) => {
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
        await connect.enterNickname(uniqueNickname("hbph"));
        await connect.registerWithPassword("pass12345");
        await new ChatPage(page).waitUntilConnected();

        await page.goto("/play/hex_blocks");
        await waitForView(page);
        const canvas = await startAndWaitForThePiece(page);
        // The buttons stand under the well on a phone held upright.
        expect(await viewOf(canvas)).toEqual({ width: 400, height: 640 });
        await expect(canvas).toBeInViewport({ ratio: 1 });
        await shot(page, "hex-blocks-phone");

        const scrolled = await page.evaluate(() => window.scrollY);
        const drop = await pagePoint(canvas, DROP);
        await changes(canvas, () => page.touchscreen.tap(drop.x, drop.y));

        // Two thumbs at once: one holds left, the other holds the turn; both buttons sink.
        const cdp = await ctx.newCDPSession(page);
        const left = await pagePoint(canvas, LEFT);
        const turn = await pagePoint(canvas, TURN);
        const both = [
          { x: left.x, y: left.y, id: 1 },
          { x: turn.x, y: turn.y, id: 2 },
        ];
        await changes(canvas, () =>
          cdp.send("Input.dispatchTouchEvent", {
            type: "touchStart",
            touchPoints: both,
          }),
        );
        await shot(canvas, "hex-blocks-phone-two-fingers");
        await changes(canvas, () =>
          cdp.send("Input.dispatchTouchEvent", {
            type: "touchEnd",
            touchPoints: [],
          }),
        );
        expect(await page.evaluate(() => window.scrollY)).toBe(scrolled);
      } finally {
        await ctx.close();
      }
    });
  });
});
