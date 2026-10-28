/**
 * @section N - P2P, File, Call, Game
 * @flow N91 [done] The pad under a keyboard game on the desktop: Hex Pong shows its cross with only the arrows it uses, the pad and End stand in sight, and a press held on the pad holds the key the game reads
 * @flow N92 [done] The pad under a keyboard game on a phone: Hex Pong fits the screen with its pad, a finger on the cross holds the arrow key down and lifting it lets go, and the page does not scroll
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
  await expect(page.getByTestId("retro-game-end-match")).toBeVisible();
  // The countdown before the serve.
  await page.waitForTimeout(3500);
  return page.getByTestId("retro-game-canvas-hex_pong").locator("canvas");
}

test.describe("The pad under a keyboard game", () => {
  test("stands under Hex Pong on the desktop, with only the arrows it uses", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "padpong");
    try {
      const game = await user.chat.openGameFromFolder("hex_pong");
      await listenForKeys(game);
      await game.reload();
      await waitForView(game);
      const canvas = await startPong(game);
      const pad = game.getByTestId("retro-game-pad");
      await expect(pad).toBeInViewport({ ratio: 1 });
      await expect(game.getByTestId("retro-game-end-match")).toBeInViewport({
        ratio: 1,
      });
      await expect(pad.locator("[data-pad-dir]")).toHaveCount(2);
      await expect(pad.locator("[data-pad-action]")).toHaveCount(0);
      await shot(game, "pad-pong-desktop");

      // A mouse held on the pad's arrow presses the key the paddle reads, until it comes up.
      const up = await centreOf(pad.locator('[data-pad-dir="up"]'));
      await game.mouse.move(up.x, up.y);
      await game.mouse.down();
      await expect.poll(() => keysHeard(game)).toEqual(["keydown ArrowUp"]);
      await game.mouse.up();
      await expect
        .poll(() => keysHeard(game))
        .toEqual(["keydown ArrowUp", "keyup ArrowUp"]);
      await expect(canvas).toBeVisible();
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
        const canvas = await startPong(page);
        const pad = page.getByTestId("retro-game-pad");
        await expect(canvas).toBeInViewport({ ratio: 1 });
        await expect(pad).toBeInViewport({ ratio: 1 });
        await shot(page, "pad-pong-phone");

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
      } finally {
        await ctx.close();
      }
    });
  });
});
