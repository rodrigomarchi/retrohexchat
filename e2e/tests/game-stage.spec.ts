/**
 * @section N - P2P, File, Call, Game
 * @flow N91 [done] A Retro Game on its stage, on the desktop: Hex Pong fills the window with its menu over it (what it plays to, its keys, the difficulty, Play vs AI) and no pad; once the match runs nothing is over the game but the corner key; Esc holds it under the Paused menu and Continue goes on; End shows the result in the menu, and Again brings the ready menu back
 * @flow N92 [done] A Retro Game on its stage, on a phone: Hex Pong and its pad fit the screen, the pad lies over the game, a finger on the cross holds the arrow key down and lifting it lets go, the page does not scroll, and the corner key opens the Paused menu
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

/**
 * Every key the window hears, as "keydown ArrowUp", from before the page's
 * own scripts: the game engine takes the keys it plays and stops them there,
 * so a listener added after it would hear nothing.
 */
const listenForKeys = (page: Page) =>
  page.context().addInitScript(() => {
    const heard: string[] = [];
    (window as unknown as { padKeys: string[] }).padKeys = heard;
    for (const type of ["keydown", "keyup"]) {
      window.addEventListener(
        type,
        (e) => heard.push(`${e.type} ${(e as KeyboardEvent).key}`),
        true,
      );
    }
  });
const keysHeard = (page: Page) =>
  page.evaluate(() => (window as unknown as { padKeys: string[] }).padKeys);

/** The middle of an element on the page. */
async function centreOf(element: Locator) {
  const box = await element.boundingBox();
  if (!box) throw new Error("the element has no box");
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
}

async function startPong(page: Page): Promise<Locator> {
  await page.evaluate(() => {
    (window as unknown as { padKeys: string[] }).padKeys.length = 0;
  });
  await page.getByTestId("retro-game-start-ai").click();
  await expect(page.getByTestId("game-stage-menu-key")).toBeVisible();
  // The countdown before the serve.
  await page.waitForTimeout(3500);
  return page.getByTestId("retro-game-canvas-hex_pong").locator("canvas");
}

test.describe("A Retro Game on its stage", () => {
  test("Hex Pong on the desktop: the menu before, nothing over the match, Esc holds it", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "stagepong");
    try {
      const game = await user.chat.openGameFromFolder("hex_pong");
      await listenForKeys(game);
      await game.reload();
      await waitForView(game);

      const menu = game.getByTestId("game-stage-menu");
      await expect(menu).toBeVisible();
      await expect(menu.getByTestId("retro-game-goal")).toHaveText(
        "First to 11",
      );
      await expect(menu.getByTestId("retro-game-controls-panel")).toBeVisible();
      await expect(game.getByTestId("retro-game-pad")).toBeHidden();
      await expect(game.getByTestId("retro-game-start-ai")).toBeInViewport({
        ratio: 1,
      });
      await game.getByTestId("retro-game-difficulty-easy").click();
      await expect(
        game.getByTestId("retro-game-difficulty-easy"),
      ).toHaveAttribute("aria-pressed", "true");
      await shot(game, "stage-ready-desktop");

      const canvas = await startPong(game);
      await expect(menu).toBeHidden();
      await expect(game.getByTestId("game-stage-menu-key")).toBeVisible();
      await expect(canvas).toBeInViewport({ ratio: 1 });
      await shot(game, "stage-playing-desktop");

      await game.keyboard.press("Escape");
      await expect(game.getByTestId("retro-game-paused")).toBeVisible();
      await expect(game.getByTestId("game-stage-menu-key")).toBeHidden();
      await shot(game, "stage-paused-desktop");

      await game.getByTestId("retro-game-resume").click();
      await expect(menu).toBeHidden();

      await game.getByTestId("game-stage-menu-key").click();
      await expect(game.getByTestId("retro-game-paused")).toBeVisible();
      await game.getByTestId("retro-game-end-match").click();
      await expect(game.getByTestId("retro-game-result")).toBeVisible();
      await expect(game.getByTestId("retro-game-ended-early")).toBeVisible();
      await shot(game, "stage-result-desktop");

      await game.getByTestId("retro-game-play-again").click();
      await expect(game.getByTestId("retro-game-start-ai")).toBeVisible();
    } finally {
      await closeUsers([user]);
    }
  });

  test.describe("on a phone", () => {
    const PIXEL_5 = devices["Pixel 5"];
    test("fits Hex Pong and its pad on the screen, and moves the paddle by touch", async ({
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
        await connect.enterNickname(uniqueNickname("padph"));
        await connect.registerWithPassword("pass12345");
        await new ChatPage(page).waitUntilConnected();

        await listenForKeys(page);
        await page.goto("/play/hex_pong");
        await waitForView(page);
        await expect(page.getByTestId("retro-game-start-ai")).toBeInViewport({
          ratio: 1,
        });
        // A touch screen is not told about keys it does not have.
        await expect(
          page.getByTestId("retro-game-controls-panel"),
        ).toBeHidden();
        await shot(page, "stage-ready-phone");

        const canvas = await startPong(page);
        const pad = page.getByTestId("retro-game-pad");
        await expect(canvas).toBeInViewport({ ratio: 1 });
        await expect(pad).toBeInViewport({ ratio: 1 });
        await expect(pad.locator("[data-pad-dir]")).toHaveCount(2);
        await expect(pad.locator("[data-pad-action]")).toHaveCount(0);
        await shot(page, "stage-playing-phone");

        const scrolled = await page.evaluate(() => window.scrollY);
        const down = pad.locator('[data-pad-dir="down"]');
        const at = await centreOf(down);
        const cdp = await ctx.newCDPSession(page);
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchStart",
          touchPoints: [{ x: at.x, y: at.y, id: 1 }],
        });
        await expect(down).toHaveAttribute("data-pressed", "");
        await expect.poll(() => keysHeard(page)).toEqual(["keydown ArrowDown"]);
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchEnd",
          touchPoints: [],
        });
        await expect(down).not.toHaveAttribute("data-pressed", "");
        await expect
          .poll(() => keysHeard(page))
          .toEqual(["keydown ArrowDown", "keyup ArrowDown"]);
        expect(await page.evaluate(() => window.scrollY)).toBe(scrolled);

        await page.getByTestId("game-stage-menu-key").tap();
        await expect(page.getByTestId("retro-game-paused")).toBeVisible();
        await expect(page.getByTestId("retro-game-resume")).toBeInViewport({
          ratio: 1,
        });
        await shot(page, "stage-paused-phone");
      } finally {
        await ctx.close();
      }
    });
  });
});
