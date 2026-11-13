/**
 * Director — the EP09 Short, "Star Duel, one ship against the computer".
 *
 * Films a YouTube Short: the shot list's frame is `phone`, so the browser is a
 * phone held upright (360x640 CSS at 3x, touch — `camera.ts`) and every press
 * is a tap. The script lives in
 * `retro_hex_chat_videos/episodes/09-star-duel-short/script.md`; its beats are
 * flows game-star-duel.spec.ts (N100) and game-stage.spec.ts (N92) prove.
 *
 * Pixel opens Star Duel from its home and fights the computer at its hardest;
 * Pixel's seat is pressed by the game's own computer player (`autopilot`) at
 * hard, the pad on screen.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { BrowserContext, expect, Page, test } from "@playwright/test";
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
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "star_duel";
const PIXEL = "Pixel";

test.describe.configure({ mode: "serial" });

test.describe("EP09 Short Star Duel against the computer", () => {
  let page: Page;
  let chat: ChatPage;
  let ctx: BrowserContext;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(4 * 60_000);
    expect(DIRECTOR_FRAME, "a Short is filmed on a phone").toBe("phone");
    ctx = await cameraContext(browser, PIXEL, { timezoneId: "Europe/Lisbon" });
    await autopilot(ctx, "hard");
    page = await ctx.newPage();
    const connect = new ConnectPage(page);
    chat = new ChatPage(page);
    await connect.open();
    await connect.signIn(PIXEL, PASSWORD);
    await chat.waitUntilConnected();
    await turnTipsOff(page, PIXEL);
    await chat.waitUntilConnected();
  });

  test.afterAll(async () => {
    await ctx?.close();
  });

  /** Off camera: only the chat's tab, the game's home over it. */
  async function homeOpen() {
    for (const tab of ctx.pages()) if (tab !== page) await tab.close();
    await page.bringToFront();
    await page.goto("/games/star-duel");
    await expect(page.getByTestId("game-home")).toBeVisible();
    await waitForView(page);
    await page.waitForTimeout(1500);
  }

  /** Off camera: the game on its stage, the menu over it. */
  async function stageOpen(): Promise<Page> {
    const open = ctx.pages().find((tab) => tab.url().endsWith(`/play/${GAME}`));
    if (open && (await stageMenu(open).isVisible())) return open;
    await homeOpen();
    return playFromHome(page, GAME, { touch: true });
  }

  test("01 a dogfight in your pocket", async () => {
    const shot = shotFor(1);
    await homeOpen();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, follow, focus, pace }) => {
        await pace(500);
        await focus(page.getByTestId("game-ways"));
        await cue("One tap from its home");
        await focus(null);
        const game = await playFromHome(page, GAME, { touch: true });
        await follow(game);
        await cue("first to seven");
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 hard", async () => {
    const shot = shotFor(2);
    const game = await stageOpen();
    await game.bringToFront();
    await filmCrew(
      { [PIXEL]: game },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await startAgainstComputer(game, { difficulty: "hard", touch: true });
        await cue("Turn, thrust and fire");
        await focus(gameCanvas(game, GAME));
        await cue("Play it free");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
