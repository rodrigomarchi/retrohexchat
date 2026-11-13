/**
 * Director — the EP08 Short, "Block Breakers, with the computer as partner".
 *
 * Films a YouTube Short: the shot list's frame is `phone`, so the browser is a
 * phone held upright (360x640 CSS at 3x, touch — `camera.ts`) and every press
 * is a tap. The script lives in
 * `retro_hex_chat_videos/episodes/08-block-breakers-short/script.md`; its
 * beats are flows game-block-breakers.spec.ts (N98), chat-retro-games.spec.ts
 * (M42) and game-stage.spec.ts (N92) prove.
 *
 * Pixel drills Start down to Block Breakers, opens it from its home, and plays
 * a board with the computer as partner at its strongest (Easy); Pixel's seat
 * is pressed by the game's own computer player (`autopilot`) at hard, the pad
 * on screen.
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
const GAME = "block_breakers";
const PIXEL = "Pixel";

test.describe.configure({ mode: "serial" });

test.describe("EP08 Short Block Breakers with the computer as partner", () => {
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

  /** Off camera: only the chat's tab, on #lobby, nothing over it. */
  async function onlyTheChat() {
    for (const tab of ctx.pages()) if (tab !== page) await tab.close();
    await page.bringToFront();
    await page.goto("/c/lobby");
    await chat.waitUntilConnected();
    await page.waitForTimeout(1500);
  }

  /** Off camera: the game on its stage, the menu over it. */
  async function stageOpen(): Promise<Page> {
    const open = ctx.pages().find((tab) => tab.url().endsWith(`/play/${GAME}`));
    if (open && (await stageMenu(open).isVisible())) return open;
    await onlyTheChat();
    await page.goto("/games/block-breakers");
    await expect(page.getByTestId("game-home")).toBeVisible();
    await waitForView(page);
    return playFromHome(page, GAME, { touch: true });
  }

  test("01 under start", async () => {
    const shot = shotFor(1);
    await onlyTheChat();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, follow, focus, pace }) => {
        await pace(500);
        await cue("Start, Games");
        await chat.startButton.tap();
        await expect(chat.startMenu).toBeVisible();
        for (const level of [
          chat.startGamesSubmenuTrigger,
          chat.startRetroGamesTrigger,
          page.getByTestId("start-menu-folder-games-action"),
        ]) {
          await pace(350);
          await level.tap();
        }
        const item = page.getByTestId("start-menu-item-game-block_breakers");
        await expect(item).toBeInViewport();
        await pace(400);
        await item.tap();
        await expect(page.getByTestId("game-home")).toBeVisible();
        await waitForView(page);
        await cue("Its home");
        await pace(600);
        const game = await playFromHome(page, GAME, { touch: true });
        await follow(game);
        await cue("clear all blocks");
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 easy means a strong partner", async () => {
    const shot = shotFor(2);
    const game = await stageOpen();
    await game.bringToFront();
    await filmCrew(
      { [PIXEL]: game },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await startAgainstComputer(game, { difficulty: "easy", touch: true });
        await cue("Your paddle is at the bottom");
        await focus(gameCanvas(game, GAME));
        await cue("Play it free");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
