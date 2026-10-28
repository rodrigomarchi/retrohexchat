/**
 * @section N - P2P, File, Call, Game
 * @flow N89 [done] Hex Blocks on the desktop: opened from the Retro Games folder, the count runs out, the pad and End stand in sight, the arrows move the piece and the space bar drops it, ended with End and written down
 * @flow N90 [done] Hex Blocks on a phone: the pad every keyboard game shares stands under the game and fits the screen, a tap on its drop button drops a piece, two fingers hold the cross and a button at once, and the page does not scroll
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

/** The picture the game draws: its canvas has twice its pixels. */
const viewOf = (canvas: Locator) =>
  canvas.evaluate((c: HTMLCanvasElement) => ({
    width: c.width / 2,
    height: c.height / 2,
  }));

const pixels = (canvas: Locator) =>
  canvas.evaluate((c: HTMLCanvasElement) => c.toDataURL("image/png"));

/** Each step's picture differs from the one before it. */
async function changes(canvas: Locator, act: () => Promise<void>) {
  const before = await pixels(canvas);
  await act();
  await expect.poll(() => pixels(canvas)).not.toBe(before);
}

/** The middle of an element on the page. */
async function centreOf(element: Locator) {
  const box = await element.boundingBox();
  if (!box) throw new Error("the element has no box");
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
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
      // The pad stands under the game on a computer too, and End stays in sight.
      await expect(game.getByTestId("retro-game-pad")).toBeInViewport({
        ratio: 1,
      });
      await expect(game.getByTestId("retro-game-end-match")).toBeInViewport({
        ratio: 1,
      });
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
    test("fits the screen and is played with two fingers on the pad", async ({
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
        // The table stands up on a phone held upright, the pad under it.
        expect(await viewOf(canvas)).toEqual({ width: 400, height: 484 });
        const pad = page.getByTestId("retro-game-pad");
        await expect(canvas).toBeInViewport({ ratio: 1 });
        await expect(pad).toBeInViewport({ ratio: 1 });
        await shot(page, "hex-blocks-phone");

        const scrolled = await page.evaluate(() => window.scrollY);
        await changes(canvas, () => pad.locator('[data-pad-action=" "]').tap());

        // Two thumbs at once: one holds left on the cross, the other the turn; both sink.
        const left = pad.locator('[data-pad-dir="left"]');
        const turn = pad.locator('[data-pad-action="x"]');
        const [l, t] = [await centreOf(left), await centreOf(turn)];
        const cdp = await ctx.newCDPSession(page);
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchStart",
          touchPoints: [
            { x: l.x, y: l.y, id: 1 },
            { x: t.x, y: t.y, id: 2 },
          ],
        });
        await expect(left).toHaveAttribute("data-pressed", "");
        await expect(turn).toHaveAttribute("data-pressed", "");
        await shot(page, "hex-blocks-phone-two-fingers");
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchEnd",
          touchPoints: [],
        });
        await expect(pad.locator("[data-pressed]")).toHaveCount(0);
        expect(await page.evaluate(() => window.scrollY)).toBe(scrolled);
      } finally {
        await ctx.close();
      }
    });
  });
});
