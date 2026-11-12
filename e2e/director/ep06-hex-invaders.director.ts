/**
 * Director — EP06, "Hex Invaders: your kills are their problem".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/06-hex-invaders/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-invaders.spec.ts: N94, N95).
 *
 * Pixel is the viewer. kestrel takes the seat Pixel offers in #hex-invaders,
 * and lumen, a regular there, watches the match; both are filmed when the
 * story is on their screen, so each has a camera browser of their own.
 * bytebard and nova are regulars nobody films.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A match lasts as long as it
 * lasts, never the same twice: scene 5 ends while it is still on, and scene 6
 * waits for it, off camera, and opens on the result.
 *
 * Each scene puts, off camera, what it needs in place — which tabs are open,
 * the home over the chat, a seat ready to start — so any one of them can be
 * retaken alone.
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
  endMatch,
  enterRoom,
  gameCanvas,
  matchCanvas,
  offerSeat,
  openTab,
  playFromHome,
  provisionGameChannel,
  recordMatch,
  stageMenu,
  startAgainstComputer,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "hex_invaders";
const COOP = "hex_invaders_coop";
const BLITZ = "hex_invaders_blitz";
const CHANNEL = "#hex-invaders";
const HOME = "/games/hex-invaders";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const LUMEN = "lumen";
const BYTEBARD = "bytebard";
const NOVA = "nova";
// Nobody films them: they make the channel a room people are in.
const REGULARS = [BYTEBARD, NOVA];

const EARLIER: Line[] = [
  { by: LUMEN, says: "new personal best on the war, 420 😤" },
  { by: NOVA, says: "the red ones are so mean" },
  { by: BYTEBARD, says: "that's the point lol" },
];

const ANYONE: Line[] = [
  { by: BYTEBARD, says: "anyone up for blitz?" },
  { by: NOVA, says: "after dinner", then: 300 },
];

type Person = TestUser;

test.describe.configure({ mode: "serial" });

test.describe("EP06 Hex Invaders", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  let lumen: Person;
  // The match room each player is in, while one is open.
  let rooms: { host: Page; guest: Page } | null = null;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    // lumen first: the founder of the game's channel, by a match in the ledger.
    lumen = await person(browser, LUMEN, "Europe/Stockholm");
    await provisionGameChannel(lumen.page.request, GAME, LUMEN);
    kestrel = await person(browser, KESTREL, "America/Chicago");
    await autopilot(kestrel.ctx, "hard");
    pixel = await person(browser, PIXEL, "Europe/Lisbon");
    await autopilot(pixel.ctx, "hard");
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    for (const member of [lumen, kestrel]) cast.adopt(member);
    for (const nick of [LUMEN, KESTREL, ...REGULARS, PIXEL]) {
      await inTheChannel(nick === PIXEL ? pixel : cast.member(nick));
    }
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
  async function inTheChannel(who: TestUser) {
    await who.page.goto(`/c/${CHANNEL.slice(1)}`);
    await who.chat.waitUntilConnected();
    await expect(who.page.getByTestId("game-channel-bar")).toBeVisible();
    await who.page.waitForTimeout(1500);
    await expect(who.chat.chatInput).toHaveAttribute(
      "placeholder",
      new RegExp(CHANNEL),
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

  /** Off camera: every tab but the chat closed, the chat in front on the channel. */
  async function onlyTheChat(who: Person) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    if (who === pixel || who === kestrel) rooms = null;
    await who.page.bringToFront();
    if (!who.page.url().includes("/c/")) await inTheChannel(who);
    await restCursor(who.page);
  }

  /** Off camera: the game's home open over Pixel's chat. */
  async function homeOpen() {
    await onlyTheChat(pixel);
    await pixel.page.goto(HOME);
    await expect(pixel.page.getByTestId("game-home")).toBeVisible();
    await waitForView(pixel.page);
    await restCursor(pixel.page);
  }

  /**
   * Off camera: Pixel and kestrel in one Blitz match, just started — what
   * scene 4 leaves, set up again when scene 5 is filmed alone.
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

  // The match between them is the war, ten waves: Blitz's instant drops can end
  // a match inside half a minute, shorter than the scenes it plays across.
  // Filmed first, though they come last: a game's channel tells a player's
  // news once every few minutes, so the match between Pixel and kestrel has to
  // be Pixel's first result here — a personal best against the computer in
  // the earlier scenes would keep it out of the channel (scene 6).
  test("04 a seat in the channel", async () => {
    const shot = shotFor(4);
    await homeOpen();
    await onlyTheChat(kestrel);
    const page = pixel.page;
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: page, [KESTREL]: kestrel.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await cast.play(ANYONE);
        await cue("Find a partner, on the first row");
        const lfg = way(page, GAME).getByTestId("game-lfg");
        await pointAt(page, lfg);
        await pace(300);
        const { card, address } = await offerSeat(page, lfg, PIXEL);
        await restCursor(page);
        await cue("puts a card with one open seat");
        await focus(card);
        await cue("Pixel steps into the match room");
        await pointAt(page, card.getByTestId("share-message-enter"));
        host = await enterRoom(page, pixel.ctx, address);
        await follow(host);
        await cue("Whoever in the channel");
        // The card in the channel, on kestrel's screen.
        layout("full", KESTREL);
        await cue("kestrel is quicker");
        await cast.say(KESTREL, "mine!");
        const kestrelCard = kestrel.page
          .locator(`[data-testid="share-message-enter"][href="${address}"]`)
          .last();
        await pointAt(kestrel.page, kestrelCard);
        guest = await enterRoom(kestrel.page, kestrel.ctx, address);
        await follow(guest);
        layout("split", PIXEL, KESTREL);
        await cue("both say they're ready");
        await bothReady(host, guest);
        await restCursor(guest);
        await cue("Pixel presses start");
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, GAME);
        await restCursor(host);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    rooms = { host: host!, guest: guest! };
  });

  test("05 live", async () => {
    const shot = shotFor(5);
    const { host, guest } = await matchRunning();
    await onlyTheChatButRooms(lumen);
    await host.bringToFront();
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest, [LUMEN]: lumen.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await focus(matchCanvas(host, GAME));
        await cue("Meanwhile, in the channel");
        layout("full", LUMEN);
        const live = lumen.page
          .getByTestId("game-channel-bar")
          .getByTestId("live-match-link");
        await expect(live).toBeVisible({ timeout: 10_000 });
        await focus(live);
        await cue("lumen follows the Watch link");
        await pointAt(lumen.page, live);
        const watch = await openTab(lumen.page, live);
        await follow(watch);
        await expect(watch.getByTestId("watch-canvas")).toBeVisible({
          timeout: 15_000,
        });
        await restCursor(watch);
        await cue("Back on the field");
        layout("split", PIXEL, KESTREL);
        // The scene is about a match still being played: one already over
        // would put its result under these lines. Retake it.
        if (await host.getByTestId("lobby-game-result").isVisible()) {
          throw new Error("the match ended during scene 5: retake 4 and 5");
        }
        await focus(matchCanvas(host, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  /** Off camera: lumen's chat in front on the channel, any watch tab closed. */
  async function onlyTheChatButRooms(who: Person) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    await who.page.bringToFront();
    await inTheChannel(who);
    await restCursor(who.page);
  }

  test("06 the result", async () => {
    const shot = shotFor(6);
    // Off camera, the match plays out — however long it takes.
    const { host, guest } = await matchRunning();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: 4 * 60_000,
      });
    }
    const card = () =>
      pixel.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: KESTREL })
        .last();
    // Scoreboard said it in the channel, on Pixel's chat behind the room. A
    // match of Pixel's announced minutes before keeps it out (once every few
    // minutes): then one like it is in the ledger instead.
    if (!(await card().isVisible())) {
      await expect(card())
        .toBeVisible({ timeout: 10_000 })
        .catch(async () => {
          await recordMatch(pixel.page.request, GAME, PIXEL, KESTREL, {
            p1: 780,
            p2: 650,
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
        await cue("posts the result");
        await focus(card());
        await cue("the week's ranking");
        const lines = pixel.page.locator(".chat-message__text");
        const before = await lines.count();
        await cast.say(BYTEBARD, "!ranking");
        // The question, then Scoreboard's answer under it.
        await expect
          .poll(() => lines.count(), { timeout: 10_000 })
          .toBeGreaterThan(before + 1);
        // The answer at the bottom of the conversation, once it has scrolled in.
        const answer = pixel.chat.messageRows.last();
        await expect(answer).toBeInViewport({ timeout: 5_000 });
        await focus(answer);
        await cue("free to play");
        await focus(null);
        await pace(0);
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await host.close();
    await guest.close();
    rooms = null;
  });

  test("00 cold open", async () => {
    const shot = shotFor(0);
    await homeOpen();
    const game = await playFromHome(pixel.page, BLITZ);
    await startAgainstComputer(game);
    // Into the first wave, the drops already falling.
    await game.waitForTimeout(9_000);
    await restCursor(game);
    await filmCrew(
      { [PIXEL]: game },
      shot,
      async ({ cue, focus }) => {
        await cue("Every alien you shoot down");
        await focus(gameCanvas(game, BLITZ));
      },
      { kind: "full", cameras: [PIXEL] },
    );
    await game.close();
  });

  test("01 hex invaders", async () => {
    const shot = shotFor(1);
    await onlyTheChat(pixel);
    // Behind the folders, #lobby: the game's channel already holds the match
    // the episode ends on (scenes 4–6 are filmed first).
    await pixel.page.goto("/");
    await pixel.chat.waitUntilConnected();
    await pixel.chat.switchToTab("#lobby");
    await restCursor(pixel.page);
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(600);
        await cue("It lives in the Games folder");
        await pointAt(page, pixel.chat.gamesFolderIcon);
        await pace(300);
        await pixel.chat.openGamesFolder();
        await pace(500);
        await pixel.chat.openCategoryOf(
          pixel.chat.gamesFolderWindow,
          `desktop-launcher-item-game-${GAME}`,
        );
        await cue("Every game has a home");
        const icon = pixel.chat.gameFolderIcon(GAME);
        await pointAt(page, icon);
        await pace(300);
        await icon.click();
        const home = page.getByTestId("game-home");
        await expect(home).toBeVisible();
        await restCursor(page);
        await cue("three ways to play");
        await focus(page.getByTestId("game-ways"));
        await cue("The war");
        await pointAt(page, way(page, GAME).locator("strong"));
        await cue("Co-op, where");
        await pointAt(page, way(page, COOP).locator("strong"));
        await cue("And Blitz");
        await pointAt(page, way(page, BLITZ).locator("strong"));
        await pace(900);
        await restCursor(page);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 against the computer", async () => {
    const shot = shotFor(2);
    await homeOpen();
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await pace(400);
        const door = way(page, GAME).getByTestId("game-play");
        await pointAt(page, door);
        await pace(300);
        const game = await openTab(page, door);
        await follow(game);
        await expect(game.getByTestId("retro-game-start-ai")).toBeVisible({
          timeout: 15_000,
        });
        await cue("The menu says");
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
        await cue("Pick how hard");
        const normal = game.getByTestId("retro-game-difficulty-normal");
        await pointAt(game, normal);
        await normal.click();
        await pace(400);
        await pointAt(game, game.getByTestId("retro-game-start-ai"));
        await game.getByTestId("retro-game-start-ai").click();
        await expect(stageMenu(game)).toBeHidden();
        await restCursor(game);
        await focus(null);
        await cue("Watch the red aliens");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 co-op", async () => {
    const shot = shotFor(3);
    // A war match running in its own tab, as scene 2 left it.
    let game = pixel.ctx
      .pages()
      .find((tab) => tab.url().endsWith(`/play/${GAME}`));
    if (!game || (await stageMenu(game).isVisible())) {
      await homeOpen();
      game = await playFromHome(pixel.page, GAME);
      await startAgainstComputer(game);
    }
    await game.bringToFront();
    await game.waitForTimeout(1_500);
    const running = game;
    await filmCrew(
      { [PIXEL]: running },
      shot,
      async ({ cue, follow, focus, pace }) => {
        await pace(300);
        await endMatch(running);
        await pace(500);
        // Back to the chat's tab; the ended match's tab closes after the take.
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await cue("The computer becomes your partner");
        const door = way(pixel.page, COOP).getByTestId("game-play");
        await pointAt(pixel.page, door);
        const coop = await openTab(pixel.page, door);
        await follow(coop);
        await expect(coop.getByTestId("retro-game-start-ai")).toBeVisible({
          timeout: 15_000,
        });
        await cue("Nothing drops on anybody");
        await startAgainstComputer(coop);
        await restCursor(coop);
        await focus(gameCanvas(coop, COOP));
      },
      { kind: "full", cameras: [PIXEL] },
    );
    await running.close();
  });
});
