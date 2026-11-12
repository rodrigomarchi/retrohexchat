/**
 * Director — the EP07 Short, "Hex Pong, from the channel".
 *
 * Films a YouTube Short: the shot list's frame is `phone`, so the browser is a
 * phone held upright (360x640 CSS at 3x, touch — `camera.ts`) and every press
 * is a tap. The script lives in
 * `retro_hex_chat_videos/episodes/07-hex-pong-short/script.md`; its beats are
 * flows game-hex-pong.spec.ts (N96) and game-stage.spec.ts (N92) prove.
 *
 * Pixel is in #hex-pong and taps Play on the game's line under the topic;
 * Pixel's seat is pressed by the game's own computer player (`autopilot`) at
 * hard, against the computer at hard, the pad on screen.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { BrowserContext, expect, Page, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { DIRECTOR_FRAME } from "./camera";
import { Cast, Line } from "./cast";
import { cameraContext, filmCrew, shotFor, turnTipsOff } from "./shots";
import {
  autopilot,
  provisionGameChannel,
  gameCanvas,
  openTab,
  stageMenu,
  startAgainstComputer,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "hex_pong";
const CHANNEL = "/c/hex-pong";
const PIXEL = "Pixel";
const LUMEN = "lumen";
const TOPIC = "First to 11, win by 2. Rematches welcome.";

// Nobody films them: the room Pixel opens is one people talk in.
const EARLIER: Line[] = [
  { by: LUMEN, says: "11 to 9, finally" },
  { by: "nova", says: "rematch tonight?" },
  { by: "bytebard", says: "the ball gets so fast" },
];

test.describe.configure({ mode: "serial" });

test.describe("EP07 Short Hex Pong from the channel", () => {
  let page: Page;
  let chat: ChatPage;
  let ctx: BrowserContext;
  let cast: Cast;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(4 * 60_000);
    expect(DIRECTOR_FRAME, "a Short is filmed on a phone").toBe("phone");
    // lumen founds the game's channel, by a match in the ledger, and sets its
    // topic; the regulars have been talking in it.
    cast = await Cast.assemble(browser, [LUMEN, "nova", "bytebard"], PASSWORD);
    await provisionGameChannel(cast.member(LUMEN).page.request, GAME, LUMEN, {
      p1: 11,
      p2: 9,
    });
    for (const nick of [LUMEN, "nova", "bytebard"]) {
      const member = cast.member(nick);
      await member.page.goto(CHANNEL);
      await member.chat.waitUntilConnected();
      await expect(member.page.getByTestId("game-channel-bar")).toBeVisible();
    }
    await cast.command(LUMEN, `/topic ${TOPIC}`);
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
    await page.goto(CHANNEL);
    await chat.waitUntilConnected();
    await expect(page.getByText(TOPIC).first()).toBeVisible();
    await cast.play(EARLIER);
  });

  test.afterAll(async () => {
    await cast?.dismiss();
    await ctx?.close();
  });

  const play = () =>
    page.getByTestId("game-channel-bar").getByTestId("game-channel-play");

  /** Off camera: only the chat's tab, on the game's channel. */
  async function inTheChannel() {
    for (const tab of ctx.pages()) if (tab !== page) await tab.close();
    await page.bringToFront();
    await page.goto(CHANNEL);
    await chat.waitUntilConnected();
    await expect(play()).toBeVisible();
    await page.waitForTimeout(1500);
  }

  /** Off camera: the game on its stage, the menu over it. */
  async function stageOpen(): Promise<Page> {
    const open = ctx.pages().find((tab) => tab.url().endsWith(`/play/${GAME}`));
    if (open && (await stageMenu(open).isVisible())) return open;
    await inTheChannel();
    return openTab(page, play(), true);
  }

  test("01 one line under the topic", async () => {
    const shot = shotFor(1);
    await inTheChannel();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await pace(500);
        await focus(page.getByTestId("game-channel-bar"));
        await cue("one tap away");
        const game = await openTab(page, play(), true);
        await follow(game);
        await expect(game.getByTestId("retro-game-start-ai")).toBeVisible({
          timeout: 15_000,
        });
        await cue("First to eleven wins");
        await focus(stageMenu(game));
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
        await cue("the edge of your paddle");
        await focus(gameCanvas(game, GAME));
        await cue("Play it free");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
