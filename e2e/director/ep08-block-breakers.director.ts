/**
 * Director — EP08, "Block Breakers: on the same side".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/08-block-breakers/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-block-breakers.spec.ts: N98, N99).
 *
 * The episode is a game played together: Pixel finds it under Start, plays a
 * board with the computer as partner, and calls kestrel in through the game's
 * channel; nova, a regular, watches the board. bytebard founds the channel and
 * talks in it with lumen; nobody films them.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A board lasts as long as it
 * lasts and may be cleared or lost: scene 4 ends while it is still on, and
 * scene 5 waits for it, off camera, and opens on how it ended.
 *
 * Filmed in the order 3, 0, 4, 5, 1, 2: the cold open is a moment of the board
 * scene 3 starts, and the pair's result is Pixel's first in the channel (a
 * game's channel tells a player's news once every few minutes).
 *
 * Each scene puts, off camera, what it needs in place, so any one of them can
 * be retaken alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { Browser, expect, Page, test } from "@playwright/test";
import { TestUser } from "../helpers/chatUsers";
import { waitForView } from "../helpers/liveView";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { Cast, Line } from "./cast";
import {
  cameraContext,
  filmCrew,
  pointAt,
  restCursor,
  shotFor,
  turnTipsOff,
} from "./shots";
import {
  autopilot,
  bothReady,
  enterRoom,
  gameCanvas,
  matchCanvas,
  offerSeat,
  openTab,
  provisionGameChannel,
  recordMatch,
  stageMenu,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "block_breakers";
const CHANNEL = "#block-breakers";
const HOME = "/games/block-breakers";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const NOVA = "nova";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
// Nobody films them: they make the channel a room people are in.
const REGULARS = [BYTEBARD, LUMEN];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "cleared it with one life left" },
  { by: LUMEN, says: "the pink row is worth fifty" },
  { by: NOVA, says: "anyone up for a board?" },
];

const TOPIC = "Two paddles, one wall. Shout when you need a partner.";

type Person = TestUser;

test.describe.configure({ mode: "serial" });

test.describe("EP08 Block Breakers", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  let nova: Person;
  // The match room each player is in, while one is open.
  let rooms: { host: Page; guest: Page } | null = null;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    // bytebard founds the game's channel, by a board in the ledger.
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      GAME,
      BYTEBARD,
      { p1: 1240, p2: 1240 },
    );
    nova = await person(browser, NOVA, "Asia/Tokyo");
    kestrel = await person(browser, KESTREL, "America/Chicago");
    await autopilot(kestrel.ctx, "hard");
    pixel = await person(browser, PIXEL, "Europe/Lisbon");
    await autopilot(pixel.ctx, "hard");
    for (const member of [nova, kestrel]) cast.adopt(member);
    for (const nick of [BYTEBARD, LUMEN, NOVA, KESTREL]) {
      await inTheChannel(cast.member(nick));
    }
    await cast.command(BYTEBARD, `/topic ${TOPIC}`);
    await expect(kestrel.page.getByText(TOPIC).first()).toBeVisible();
    await cast.play(EARLIER);
  });

  test.afterAll(async () => {
    await cast?.dismiss();
    await pixel?.ctx.close();
  });

  /**
   * Off camera: in the game's channel at its own address, the way
   * game-channels.spec.ts opens it — the address wins over whatever channel
   * the last session ended in, and keeps winning once the restore has run.
   */
  async function inTheChannel(who: TestUser, channel = CHANNEL) {
    await who.page.goto(`/c/${channel.slice(1)}`);
    await who.chat.waitUntilConnected();
    await who.page.waitForTimeout(1500);
    await expect(who.chat.chatInput).toHaveAttribute(
      "placeholder",
      new RegExp(channel),
    );
  }

  /** Someone on film: a camera browser, signed in, tips off. */
  async function person(
    browser: Browser,
    nick: string,
    timezoneId: string,
  ): Promise<Person> {
    const ctx = await cameraContext(browser, nick, { timezoneId });
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.signIn(nick, PASSWORD);
    await chat.waitUntilConnected();
    await turnTipsOff(page, nick);
    await chat.waitUntilConnected();
    return { nick, chat, connect, page, ctx, password: PASSWORD };
  }

  /**
   * Off camera: every tab but the chat closed, the chat in front on
   * `channel`, nothing over it.
   */
  async function onlyTheChat(who: Person, channel = CHANNEL) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    if (who === pixel || who === kestrel) rooms = null;
    await who.page.bringToFront();
    await inTheChannel(who, channel);
    await restCursor(who.page);
  }

  /** Off camera: Pixel's chat with the game's home open over it. */
  async function homeOpen() {
    await onlyTheChat(pixel, "#lobby");
    await pixel.page.goto(HOME);
    await expect(pixel.page.getByTestId("game-home")).toBeVisible();
    await waitForView(pixel.page);
    await restCursor(pixel.page);
  }

  /**
   * Off camera: Pixel and kestrel on one board, just started — what scene 3
   * leaves, set up again when a later scene is filmed alone.
   */
  async function matchRunning(): Promise<{ host: Page; guest: Page }> {
    if (rooms && !rooms.host.isClosed() && !rooms.guest.isClosed()) {
      return rooms;
    }
    await homeOpen();
    await onlyTheChat(kestrel);
    const { address } = await offerSeat(
      pixel.page,
      way(pixel.page, GAME).getByTestId("game-lfg"),
      PIXEL,
    );
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, GAME);
    rooms = { host, guest };
    return rooms;
  }

  test("03 a seat at the other end", async () => {
    const shot = shotFor(3);
    await homeOpen();
    await onlyTheChat(kestrel);
    const page = pixel.page;
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: page, [KESTREL]: kestrel.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(400);
        await cue("Find a partner takes Pixel");
        const lfg = way(page, GAME).getByTestId("game-lfg");
        await pointAt(page, lfg);
        await pace(300);
        const { card, address } = await offerSeat(page, lfg, PIXEL);
        await restCursor(page);
        await focus(card);
        await cue("Pixel takes one end");
        await pointAt(page, card.getByTestId("share-message-enter"));
        host = await enterRoom(page, pixel.ctx, address);
        await follow(host);
        await cue("kestrel is in the room");
        // The card in the channel, on kestrel's screen.
        layout("full", KESTREL);
        await cast.say(KESTREL, "I'll take the top");
        const kestrelCard = kestrel.page
          .locator(`[data-testid="share-message-enter"][href="${address}"]`)
          .last();
        await pointAt(kestrel.page, kestrelCard);
        guest = await enterRoom(kestrel.page, kestrel.ctx, address);
        await follow(guest);
        layout("split", PIXEL, KESTREL);
        await cue("Both say they're ready");
        await bothReady(host, guest);
        await restCursor(guest);
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, GAME);
        await restCursor(host);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    rooms = { host: host!, guest: guest! };
  });

  test("00 cold open", async () => {
    const shot = shotFor(0);
    const { host, guest } = await matchRunning();
    await host.bringToFront();
    // Into the board, past the countdown and the first serve.
    await host.waitForTimeout(5_000);
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue("kestrel guards the top");
        await focus(matchCanvas(guest, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("04 two ends of one wall", async () => {
    const shot = shotFor(4);
    const { host, guest } = await matchRunning();
    await onlyTheChat(nova);
    await host.bringToFront();
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest, [NOVA]: nova.page },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(matchCanvas(host, GAME));
        await cue("A ball past either paddle");
        await focus(matchCanvas(guest, GAME));
        await cue("the channel knows a match is on");
        layout("full", NOVA);
        const live = nova.page
          .getByTestId("game-channel-bar")
          .getByTestId("live-match-link");
        await expect(live).toBeVisible({ timeout: 10_000 });
        await focus(live);
        await cue("nova follows the link");
        await pointAt(nova.page, live);
        const watch = await openTab(nova.page, live);
        await follow(watch);
        await expect(watch.getByTestId("watch-canvas")).toBeVisible({
          timeout: 15_000,
        });
        await restCursor(watch);
        await cue("Back on the board");
        layout("split", PIXEL, KESTREL);
        // The scene is about a board still being played: one already over
        // would put its result under these lines. Retake it.
        if (await host.getByTestId("lobby-game-result").isVisible()) {
          throw new Error("the board ended during scene 4: retake 3, 0 and 4");
        }
        await focus(matchCanvas(host, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("05 however it ends", async () => {
    const shot = shotFor(5);
    test.setTimeout(10 * 60_000);
    // Off camera, the board plays out — however long it takes: two paddles at
    // hard clear it or lose it in one to three minutes.
    const { host, guest } = await matchRunning();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: 7 * 60_000,
      });
    }
    const card = () =>
      pixel.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: KESTREL })
        .last();
    // Scoreboard said it in the channel, on Pixel's chat behind the room. A
    // board of Pixel's announced minutes before keeps it out (once every few
    // minutes): then one like it is in the ledger instead.
    if (!(await card().isVisible())) {
      await expect(card())
        .toBeVisible({ timeout: 10_000 })
        .catch(async () => {
          await recordMatch(pixel.page.request, GAME, PIXEL, KESTREL, {
            p1: 980,
            p2: 980,
          });
          await expect(card()).toBeVisible({ timeout: 15_000 });
        });
    }
    await card().scrollIntoViewIfNeeded();
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await focus(host.getByTestId("lobby-game-result"));
        await cue("The channel hears about it");
        layout("full", PIXEL);
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await restCursor(pixel.page);
        await cue("posts the pair's score");
        await focus(card());
        await cue("free to play");
        await cast.say(KESTREL, "same time tomorrow?");
        await focus(null);
        await pace(0);
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await host.close();
    await guest.close();
    rooms = null;
  });

  test("01 under start", async () => {
    const shot = shotFor(1);
    await onlyTheChat(pixel, "#lobby");
    const page = pixel.page;
    const chat = pixel.chat;
    // Off camera, the chat settles: a late re-render closes an open Start menu.
    await page.waitForTimeout(3_000);
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(600);
        await pointAt(page, chat.startButton);
        await chat.openStartMenu();
        const path = [
          chat.startGamesSubmenuTrigger,
          chat.startRetroGamesTrigger,
          page.getByTestId("start-menu-folder-games-action"),
        ];
        // One level at a time, the pointer on each; the walk retries the way
        // the suite's does when a re-render closes the menu under it.
        for (let depth = 1; depth <= path.length; depth++) {
          await expect(async () => {
            await chat.openStartPath(path.slice(0, depth - 1));
            await pointAt(page, path[depth - 1]);
          }).toPass({ timeout: 15_000 });
          await pace(250);
          await chat.openStartPath(path.slice(0, depth));
        }
        const item = page.getByTestId("start-menu-item-game-block_breakers");
        await expect(async () => {
          await chat.openStartPath(path, item);
          await pointAt(page, item);
        }).toPass({ timeout: 15_000 });
        await cue("Its home opens");
        await expect(async () => {
          await chat.openStartPath(path, item);
          await item.click({ timeout: 1_000 });
        }).toPass({ timeout: 15_000 });
        await expect(page.getByTestId("game-home")).toBeVisible();
        await waitForView(page);
        await restCursor(page);
        await cue("one way to play");
        await focus(page.getByTestId("game-ways"));
        await cue("Your partner can be the computer");
        await pointAt(page, way(page, GAME).getByTestId("game-play"));
        await pace(700);
        await pointAt(page, way(page, GAME).getByTestId("game-lfg"));
        await pace(600);
        await restCursor(page);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 a partner who never gets tired", async () => {
    const shot = shotFor(2);
    await homeOpen();
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await pace(400);
        const play = way(page, GAME).getByTestId("game-play");
        await pointAt(page, play);
        const game = await openTab(page, play);
        await follow(game);
        await expect(game.getByTestId("retro-game-start-ai")).toBeVisible({
          timeout: 15_000,
        });
        await cue("The goal fits in four words");
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
        await cue("the difficulty picks your partner");
        const easy = game.getByTestId("retro-game-difficulty-easy");
        await pointAt(game, easy);
        await cue("Easy gives you the computer");
        await easy.click();
        await focus(easy);
        await cue("Pixel has the bottom paddle");
        await focus(null);
        await pointAt(game, game.getByTestId("retro-game-start-ai"));
        await game.getByTestId("retro-game-start-ai").click();
        await expect(stageMenu(game)).toBeHidden();
        await restCursor(game);
        await cue("The higher the row");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
