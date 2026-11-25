/**
 * Director — EP10, "Gravity Well: a duel with an audience".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/10-gravity-well/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-gravity-well.spec.ts: N102, N103).
 *
 * The episode is a duel in front of the room: Pixel finds the game on
 * #gravity-well's line, practises against the computer, and offers a seat in
 * the channel; kestrel takes it, and nova, a regular who does not play,
 * watches it from the line under the topic. bytebard founds the channel and
 * talks in it with lumen; nobody films them.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A duel lasts as long as it
 * lasts and either may win: scene 4 ends while it is still on, and scene 5
 * waits for it, off camera, and opens on how it ended.
 *
 * Filmed in the order 1, 3, 4, 0, 5, 2: scene 1 shows the channel before the
 * duel, so it goes first, while the room holds only what was said before;
 * the cold open is nova's watch window, which scene 4 opens; and the duel's
 * result is Pixel's first in the channel (a game's channel tells a player's
 * news once every few minutes), so the practice against the computer comes
 * last.
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
const GAME = "gravity_well";
const CHANNEL = "#gravity-well";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const NOVA = "nova";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
// Nobody films them: they make the channel a room people are in.
const REGULARS = [BYTEBARD, LUMEN];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "slingshot round the star, then fire" },
  { by: LUMEN, says: "I keep falling in" },
  { by: NOVA, says: "anyone duelling tonight? I'll watch" },
];

const TOPIC = "One star, two ships. Duels every night, watchers welcome.";

type Person = TestUser;

test.describe.configure({ mode: "serial" });

test.describe("EP10 Gravity Well", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  let nova: Person;
  // The match room each player is in, while one is open.
  let rooms: { host: Page; guest: Page } | null = null;
  // nova's window on the duel, while one is open.
  let watching: Page | null = null;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    // bytebard founds the game's channel, by a duel in the ledger.
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      GAME,
      BYTEBARD,
      { p1: 7, p2: 4 },
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
    if (who === nova) watching = null;
    await who.page.bringToFront();
    await inTheChannel(who, channel);
    await restCursor(who.page);
  }

  /** The game's line under #gravity-well's topic, on `page`. */
  const line = (page: Page) => page.getByTestId("game-channel-bar");

  /** Off camera: Pixel's chat with the game's home open over it. */
  async function homeOpen() {
    await onlyTheChat(pixel);
    await line(pixel.page).getByTestId("game-channel-home").click();
    await expect(pixel.page.getByTestId("game-home")).toBeVisible();
    await waitForView(pixel.page);
    await restCursor(pixel.page);
  }

  /**
   * Off camera: Pixel and kestrel in one duel, just started — what scene 3
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
      line(pixel.page).getByTestId("game-channel-lfg"),
      PIXEL,
    );
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, GAME);
    rooms = { host, guest };
    return rooms;
  }

  /** The duel's live link at the end of the game's line, on nova's chat. */
  const liveLink = () => line(nova.page).getByTestId("live-match-link");

  /** Off camera: nova watching the duel in a window of its own. */
  async function novaWatching(): Promise<Page> {
    await matchRunning();
    if (watching && !watching.isClosed()) return watching;
    await onlyTheChat(nova);
    await expect(liveLink()).toBeVisible({ timeout: 15_000 });
    watching = await openTab(nova.page, liveLink());
    await liveFrames(watching);
    return watching;
  }

  /** The watch window, once the host's frames reach it. */
  async function liveFrames(watch: Page) {
    const canvas = watch.getByTestId("watch-canvas");
    await expect
      .poll(async () => Number(await canvas.getAttribute("data-frames")), {
        timeout: 30_000,
      })
      .toBeGreaterThan(0);
  }

  test("01 a star in the middle", async () => {
    const shot = shotFor(1);
    await onlyTheChat(pixel);
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(500);
        await focus(page.getByTestId("topic-bar").first());
        await cue("The line under the topic");
        await focus(line(page));
        await pointAt(page, line(page));
        await cue("The game's name opens its home");
        const home = line(page).getByTestId("game-channel-home");
        await pointAt(page, home);
        await home.click();
        await expect(page.getByTestId("game-home")).toBeVisible();
        await waitForView(page);
        await restCursor(page);
        await cue("One way to play");
        await focus(way(page, GAME));
        await pointAt(page, way(page, GAME).getByTestId("game-play"));
        await pace(700);
        await pointAt(page, way(page, GAME).getByTestId("game-lfg"));
        await pace(500);
        await restCursor(page);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 a seat in the channel", async () => {
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
        await pace(300);
        await cue("Find a partner puts a seat");
        const lfg = line(page).getByTestId("game-channel-lfg");
        await pointAt(page, lfg);
        const { card, address } = await offerSeat(page, lfg, PIXEL);
        await restCursor(page);
        await focus(card);
        await cue("Pixel goes in first");
        await pointAt(page, card.getByTestId("share-message-enter"));
        host = await enterRoom(page, pixel.ctx, address);
        await follow(host);
        await cue("kestrel was already in the room");
        // The card in the channel, on kestrel's screen.
        layout("full", KESTREL);
        await cast.say(KESTREL, "I'm in");
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

  test("04 pull up a chair", async () => {
    const shot = shotFor(4);
    const { host, guest } = await matchRunning();
    await onlyTheChat(nova);
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest, [NOVA]: nova.page },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(matchCanvas(host, GAME));
        await cue("the channel knows a match is on");
        layout("full", NOVA);
        await expect(liveLink()).toBeVisible({ timeout: 10_000 });
        await cue("Its line now shows");
        await focus(liveLink());
        await cue("nova follows it");
        await pointAt(nova.page, liveLink());
        const watch = await openTab(nova.page, liveLink());
        await follow(watch);
        await liveFrames(watch);
        await restCursor(watch);
        watching = watch;
        await cue("Watching needs no seat");
        await focus(watch.getByTestId("watch-canvas"));
        await cue("On Pixel's side");
        layout("full", PIXEL);
        await pointAt(host, host.getByTestId("game-stage-menu-key"));
        await host.getByTestId("game-stage-menu-key").click();
        const watchers = host.getByTestId("lobby-game-watchers");
        await expect(watchers).toContainText("1 watching", {
          timeout: 10_000,
        });
        await focus(watchers);
        await cue("Back to it");
        await pointAt(host, host.getByTestId("lobby-game-resume"));
        await host.getByTestId("lobby-game-resume").click();
        await restCursor(host);
        layout("split", PIXEL, KESTREL);
        // The scene is about a duel still being flown: one already over
        // would put its result under these lines. Retake it.
        if (await host.getByTestId("lobby-game-result").isVisible()) {
          throw new Error("the duel ended during scene 4: retake 3 and 4");
        }
        await focus(matchCanvas(host, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("00 cold open", async () => {
    const shot = shotFor(0);
    const watch = await novaWatching();
    await watch.bringToFront();
    await restCursor(watch);
    await filmCrew(
      { [NOVA]: watch },
      shot,
      async ({ cue, focus }) => {
        await focus(watch.getByTestId("watch-canvas"));
        await cue("That's nova");
        await focus(watch.getByTestId("watch-watchers"));
        await cue("Not playing tonight");
        await focus(null);
      },
      { kind: "full", cameras: [NOVA] },
    );
    // The duel has to be over in scene 5, and nova back in the channel.
  });

  test("05 seven, in front of everyone", async () => {
    const shot = shotFor(5);
    test.setTimeout(10 * 60_000);
    // Off camera, the duel plays out — however long it takes: two ships at
    // hard round the star reach seven in one to three minutes.
    const { host, guest } = await matchRunning();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: 7 * 60_000,
      });
    }
    await onlyTheChat(nova);
    const card = () =>
      nova.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: KESTREL })
        .filter({ hasText: PIXEL })
        .last();
    // Scoreboard said it in the channel. A duel of Pixel's announced minutes
    // before keeps it out (once every few minutes): then one like it is in
    // the ledger instead.
    await expect(card())
      .toBeVisible({ timeout: 15_000 })
      .catch(async () => {
        await recordMatch(nova.page.request, GAME, PIXEL, KESTREL, {
          p1: 7,
          p2: 6,
        });
        await expect(card()).toBeVisible({ timeout: 15_000 });
      });
    await card().scrollIntoViewIfNeeded();
    await host.bringToFront();
    await guest.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest, [NOVA]: nova.page },
      shot,
      async ({ cue, focus, layout, pace }) => {
        await focus(host.getByTestId("lobby-game-result"));
        await cue("And the result lands in the channel");
        layout("full", NOVA);
        await restCursor(nova.page);
        await focus(card());
        await cast.say(NOVA, "what a finish");
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

  test("02 learning the star", async () => {
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
        await cue("The rule is short");
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
        await cue("On hard");
        const hard = game.getByTestId("retro-game-difficulty-hard");
        await pointAt(game, hard);
        await hard.click();
        await focus(null);
        await pointAt(game, game.getByTestId("retro-game-start-ai"));
        await game.getByTestId("retro-game-start-ai").click();
        await expect(stageMenu(game)).toBeHidden();
        await restCursor(game);
        await cue("The star pulls everything");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
