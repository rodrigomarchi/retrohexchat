/**
 * Director — the EP06 Short, "Hex Invaders, on your phone".
 *
 * Films a YouTube Short: the shot list's frame is `phone`, so the browser is a
 * phone held upright (360x640 CSS at 3x, touch — `camera.ts`) and every press
 * is a tap. The script lives in
 * `retro_hex_chat_videos/episodes/06-hex-invaders-short/script.md`; its beats
 * are flows game-hex-invaders.spec.ts (N94) and game-stage.spec.ts (N92) prove.
 *
 * Pixel plays Blitz against the computer; Pixel's seat is pressed by the
 * game's own computer player (`autopilot`) at hard, the pad on screen.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { expect, Page, test } from "@playwright/test";
import { waitForView } from "../helpers/liveView";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { DIRECTOR_FRAME } from "./camera";
import { cameraContext, filmCrew, shotFor, turnTipsOff } from "./shots";
import {
  autopilot,
  gameCanvas,
  playFromHome,
  stageMenu,
  startAgainstComputer,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const BLITZ = "hex_invaders_blitz";
const HOME = "/games/hex-invaders";
const PIXEL = "Pixel";

test.describe.configure({ mode: "serial" });

test.describe("EP06 Short Hex Invaders on your phone", () => {
  let page: Page;
  let ctx: import("@playwright/test").BrowserContext;

  test.beforeAll(async ({ browser }) => {
    expect(DIRECTOR_FRAME, "a Short is filmed on a phone").toBe("phone");
    ctx = await cameraContext(browser, PIXEL, { timezoneId: "Europe/Lisbon" });
    await autopilot(ctx, "hard");
    page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.signIn(PIXEL, PASSWORD);
    await chat.waitUntilConnected();
    await turnTipsOff(page, PIXEL);
    await chat.waitUntilConnected();
  });

  test.afterAll(async () => {
    await ctx?.close();
  });

  /** Off camera: only the chat's tab, with the game's home over it, at the Blitz row. */
  async function homeOpen() {
    for (const tab of ctx.pages()) if (tab !== page) await tab.close();
    await page.bringToFront();
    await page.goto(HOME);
    await expect(page.getByTestId("game-home")).toBeVisible();
    await waitForView(page);
    await way(page, BLITZ).scrollIntoViewIfNeeded();
  }

  /** Off camera: Blitz on its stage, the menu over it. */
  async function stageOpen(): Promise<Page> {
    const open = ctx
      .pages()
      .find((tab) => tab.url().endsWith(`/play/${BLITZ}`));
    if (open && (await stageMenu(open).isVisible())) return open;
    await homeOpen();
    return playFromHome(page, BLITZ, { touch: true });
  }

  test("01 on your phone", async () => {
    const shot = shotFor(1);
    await homeOpen();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await pace(500);
        await focus(page.getByTestId("game-ways"));
        await cue("Blitz is the quick one");
        const game = await playFromHome(page, BLITZ, { touch: true });
        await follow(game);
        await focus(stageMenu(game));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 blitz", async () => {
    const shot = shotFor(2);
    const game = await stageOpen();
    await game.bringToFront();
    await filmCrew(
      { [PIXEL]: game },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await startAgainstComputer(game, { touch: true });
        await cue("See the red ones");
        await focus(gameCanvas(game, BLITZ));
        await cue("Play it free");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
