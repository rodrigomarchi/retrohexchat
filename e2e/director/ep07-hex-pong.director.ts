/**
 * Director — EP07, "Hex Pong: first to eleven".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/07-hex-pong/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-pong.spec.ts: N96, N97).
 *
 * The episode is told from the game's channel: everything Pixel does starts on
 * the game's line under #hex-pong's topic. kestrel takes the seat Pixel offers
 * there, and lumen, a regular, watches the match; both are filmed when the
 * story is on their screen. bytebard and nova are regulars nobody films.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A match lasts as long as it
 * lasts: scene 4 ends while it is still on, and scene 5 waits for it, off
 * camera, and opens on the result.
 *
 * Filmed in the order 1, 2, 3, 0, 4, 5: the cold open is a moment of the match
 * scene 3 starts. Scene 2's match against the computer is never finished, so
 * the match between Pixel and kestrel is Pixel's first result in the channel
 * (a game's channel tells a player's news once every few minutes).
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
  startAgainstComputer,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "hex_pong";
const CHANNEL = "#hex-pong";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const LUMEN = "lumen";
const BYTEBARD = "bytebard";
const NOVA = "nova";
// Nobody films them: they make the channel a room people are in.
const REGULARS = [BYTEBARD, NOVA];

const EARLIER: Line[] = [
  { by: LUMEN, says: "11 to 9, finally" },
  { by: NOVA, says: "rematch tonight?" },
  { by: BYTEBARD, says: "the ball gets so fast" },
];

const TOPIC = "First to 11, win by 2. Rematches welcome.";

type Person = TestUser;

test.describe.configure({ mode: "serial" });

test.describe("EP07 Hex Pong", () => {
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
    await provisionGameChannel(lumen.page.request, GAME, LUMEN, {
      p1: 11,
      p2: 9,
    });
    kestrel = await person(browser, KESTREL, "America/Chicago");
    await autopilot(kestrel.ctx, "hard");
    pixel = await person(browser, PIXEL, "Europe/Lisbon");
    await autopilot(pixel.ctx, "hard");
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    for (const member of [lumen, kestrel]) cast.adopt(member);
    for (const nick of [LUMEN, KESTREL, ...REGULARS, PIXEL]) {
      await inTheChannel(nick === PIXEL ? pixel : cast.member(nick));
    }
    // The founder's topic: the game's line sits right under it.
    await cast.command(LUMEN, `/topic ${TOPIC}`);
    await expect(pixel.page.getByText(TOPIC).first()).toBeVisible();
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

  /**
   * Off camera: every tab but the chat closed, the chat in front on the
   * channel, nothing over it.
   */
  async function onlyTheChat(who: Person) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    if (who === pixel || who === kestrel) rooms = null;
    await who.page.bringToFront();
    await inTheChannel(who);
    await restCursor(who.page);
  }

  /** The game's line under the channel's topic. */
  const gameLine = (page: Page) => page.getByTestId("game-channel-bar");

  /**
   * Off camera: Pixel and kestrel in one match, just started — what scene 3
   * leaves, set up again when a later scene is filmed alone.
   */
  async function matchRunning(): Promise<{ host: Page; guest: Page }> {
    if (rooms && !rooms.host.isClosed() && !rooms.guest.isClosed()) {
      return rooms;
    }
    await onlyTheChat(pixel);
    await onlyTheChat(kestrel);
    const { address } = await offerSeat(
      pixel.page,
      gameLine(pixel.page).getByTestId("game-channel-lfg"),
      PIXEL,
    );
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, GAME);
    rooms = { host, guest };
    return rooms;
  }

  test("01 a room with a game in it", async () => {
    const shot = shotFor(1);
    await onlyTheChat(pixel);
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(600);
        await cue("one line under the topic");
        await focus(gameLine(page));
        await cue("Press its name");
        const name = gameLine(page).getByTestId("game-channel-home");
        await pointAt(page, name);
        await pace(300);
        await name.click();
        await expect(page.getByTestId("game-home")).toBeVisible();
        await waitForView(page);
        await restCursor(page);
        await focus(null);
        await cue("one way to play");
        await focus(page.getByTestId("game-ways"));
        await cue("Against the computer, or against a person");
        await pointAt(page, way(page, GAME).getByTestId("game-play"));
        await pace(700);
        await pointAt(page, way(page, GAME).getByTestId("game-lfg"));
        await pace(600);
        await restCursor(page);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 warming up", async () => {
    const shot = shotFor(2);
    await onlyTheChat(pixel);
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await pace(400);
        await cue("Play opens the game");
        const play = gameLine(page).getByTestId("game-channel-play");
        await pointAt(page, play);
        const game = await openTab(page, play);
        await follow(game);
        await expect(game.getByTestId("retro-game-start-ai")).toBeVisible({
          timeout: 15_000,
        });
        await cue("The menu says what it takes");
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
        await cue("Easy, to start with");
        const easy = game.getByTestId("retro-game-difficulty-easy");
        await pointAt(game, easy);
        await easy.click();
        await pace(300);
        await pointAt(game, game.getByTestId("retro-game-start-ai"));
        await game.getByTestId("retro-game-start-ai").click();
        await expect(stageMenu(game)).toBeHidden();
        await restCursor(game);
        await focus(null);
        await cue("Pixel has the paddle on the left");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 a seat for the room", async () => {
    const shot = shotFor(3);
    await onlyTheChat(pixel);
    await onlyTheChat(kestrel);
    const page = pixel.page;
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: page, [KESTREL]: kestrel.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(400);
        await cue("Find a partner, on the same line");
        const lfg = gameLine(page).getByTestId("game-channel-lfg");
        await pointAt(page, lfg);
        await pace(300);
        const { card, address } = await offerSeat(page, lfg, PIXEL);
        await restCursor(page);
        await cue("A card lands in the conversation");
        await focus(card);
        await cue("Pixel takes the first seat");
        await pointAt(page, card.getByTestId("share-message-enter"));
        host = await enterRoom(page, pixel.ctx, address);
        await follow(host);
        await cue("Whoever presses Join first");
        // The card in the channel, on kestrel's screen.
        layout("full", KESTREL);
        await cue("kestrel wants a rematch");
        await cast.say(KESTREL, "rematch!");
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
    // Into the match, past the countdown and the first serve.
    await host.waitForTimeout(5_000);
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue("Every hit makes the ball");
        await focus(matchCanvas(guest, GAME));
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

  test("04 a rally on the wire", async () => {
    const shot = shotFor(4);
    const { host, guest } = await matchRunning();
    await onlyTheChatButRooms(lumen);
    await host.bringToFront();
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest, [LUMEN]: lumen.page },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(matchCanvas(host, GAME));
        await cue("kestrel defends the right side");
        await focus(matchCanvas(guest, GAME));
        await cue("the room knows a match is on");
        layout("full", LUMEN);
        const live = gameLine(lumen.page).getByTestId("live-match-link");
        await expect(live).toBeVisible({ timeout: 10_000 });
        await focus(live);
        await cue("lumen follows it");
        await pointAt(lumen.page, live);
        const watch = await openTab(lumen.page, live);
        await follow(watch);
        await expect(watch.getByTestId("watch-canvas")).toBeVisible({
          timeout: 15_000,
        });
        await restCursor(watch);
        await cue("Back at the table");
        layout("split", PIXEL, KESTREL);
        // The scene is about a match still being played: one already over
        // would put its result under these lines. Retake it.
        if (await host.getByTestId("lobby-game-result").isVisible()) {
          throw new Error("the match ended during scene 4: retake 3, 0 and 4");
        }
        await focus(matchCanvas(host, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("05 eleven", async () => {
    const shot = shotFor(5);
    test.setTimeout(18 * 60_000);
    // Off camera, the match plays out — however long it takes: two computer
    // players at eleven by two need four to eight minutes, twelve at worst.
    const { host, guest } = await matchRunning();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: 14 * 60_000,
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
            p1: 11,
            p2: 8,
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
        await cue("The room hears about it");
        layout("full", PIXEL);
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await restCursor(pixel.page);
        await cue("posts the result");
        await focus(card());
        await cue("Press the game's name on that card");
        const name = card().getByTestId("game-result-home");
        await pointAt(pixel.page, name);
        await name.click();
        await expect(pixel.page.getByTestId("game-home")).toBeVisible();
        await waitForView(pixel.page);
        const you = pixel.page.getByTestId("game-home-tab-you");
        await pointAt(pixel.page, you);
        await you.click();
        await expect(pixel.page.getByTestId("game-you-rating")).toBeVisible();
        await restCursor(pixel.page);
        await focus(pixel.page.getByTestId("game-you-recent"));
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
});
