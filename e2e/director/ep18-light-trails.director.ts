/**
 * Director — EP18, "Light Trails: from the stands".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/18-light-trails/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-light-trails.spec.ts: N118, N119, N120).
 *
 * The episode is told from the stands. kestrel and nova play a match made
 * with Find a partner; Pixel finds it under #light-trails' topic and on the
 * Live tab of the game's home, and watches it in a tab of its own to the end.
 * Then Pixel takes a seat: Find a partner, taken by whoever won, while the
 * one who lost watches Pixel's match from the channel. bytebard founds
 * #light-trails and talks in it with lumen; nobody films them.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), all at hard. A scene during a match fails,
 * to be retaken, if the match ends before it does; the scene after waits for
 * the result off camera. Before the first match's end, a scene that finds it
 * over starts another between the same two, off camera: the story only needs
 * one being played.
 *
 * Filmed in the order 1, 2, 3, 0, 4, 5, 6, 7: the first match while it is on,
 * the cold open from it, its end, then Pixel's.
 *
 * Each scene puts, off camera, what it needs in place, so any one of them can
 * be retaken alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { Browser, expect, Locator, Page, test } from "@playwright/test";
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
  matchCanvas,
  offerSeat,
  provisionGameChannel,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "light_trails";
const CHANNEL = "#light-trails";
const HOME = "/games/light-trails";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const NOVA = "nova";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const REGULARS = [BYTEBARD, LUMEN];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "kestrel and nova are at it again" },
  { by: LUMEN, says: "first to three, I'm watching this one" },
];

/** How long a match between two hard cycles may take, and some to spare. */
const MATCH_TIMEOUT = 5 * 60_000;

type Person = TestUser;
type Rooms = { host: Page; guest: Page; token: string };
type Match = {
  host: string;
  guest: string;
  rooms: Rooms | null;
  over: boolean;
};

test.describe.configure({ mode: "serial" });

test.describe("EP18 Light Trails", () => {
  let cast: Cast;
  const people: Record<string, Person> = {};
  // The friends' match, then Pixel's against whoever won it.
  const first: Match = { host: KESTREL, guest: NOVA, rooms: null, over: false };
  const second: Match = { host: PIXEL, guest: "", rooms: null, over: false };
  let winner = "";
  let loser = "";

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      GAME,
      BYTEBARD,
      { p1: 3, p2: 1 },
    );
    const zones: Record<string, string> = {
      [PIXEL]: "Europe/Lisbon",
      [KESTREL]: "America/Chicago",
      [NOVA]: "Europe/Berlin",
    };
    for (const [nick, zone] of Object.entries(zones)) {
      people[nick] = await person(browser, nick, zone);
      await autopilot(people[nick].ctx, "hard");
      cast.adopt(people[nick]);
    }
    for (const who of [
      ...REGULARS.map((n) => cast.member(n)),
      ...Object.values(people),
    ]) {
      await inTheChannel(who);
    }
    await cast.play(EARLIER);
  });

  test.afterAll(async () => {
    await cast?.dismiss();
  });

  /** Off camera: in the channel at its own address, the restore run. */
  async function inTheChannel(who: TestUser) {
    await who.page.goto(`/c/${CHANNEL.slice(1)}`);
    await who.chat.waitUntilConnected();
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

  /** Off camera: every tab but the chat closed, the chat in front, in the channel. */
  async function onlyTheChat(who: Person, keep: Page[] = []) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page && !keep.includes(tab)) await tab.close();
    }
    await who.page.bringToFront();
    await inTheChannel(who);
    await restCursor(who.page);
  }

  /** Off camera: Pixel's chat with the game's home open over it, on `tab`. */
  async function homeOpen(tab: "play" | "live" = "play") {
    const pixel = people[PIXEL];
    await onlyTheChat(pixel);
    await pixel.page.goto(HOME);
    await expect(pixel.page.getByTestId("game-home")).toBeVisible();
    await waitForView(pixel.page);
    if (tab !== "play")
      await pixel.page.getByTestId(`game-home-tab-${tab}`).click();
    await pixel.page.waitForTimeout(1000);
    await restCursor(pixel.page);
  }

  const liveLink = (where: Locator, token: string) =>
    where.locator(`[data-testid="live-match-link"][data-token="${token}"]`);
  const channelBar = (who: Person) => who.page.getByTestId("game-channel-bar");
  const seatCard = (who: Person, address: string) =>
    who.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();
  const watchCanvas = (watch: Page) => watch.getByTestId("watch-canvas");

  /** Whether `match` is being played in rooms that are open. */
  async function on(match: Match): Promise<boolean> {
    const rooms = match.rooms;
    if (!rooms || rooms.host.isClosed() || rooms.guest.isClosed()) return false;
    return !(await rooms.host.getByTestId("lobby-game-result").isVisible());
  }

  /** Off camera: `match`'s session ended and its rooms closed. */
  async function closeSession(match: Match) {
    const rooms = match.rooms;
    if (!rooms) return;
    if (!rooms.host.isClosed()) {
      await rooms.host.getByTestId("p2p-console-end-session").click();
      await rooms.host.getByTestId("p2p-confirm-dialog-confirm").click();
      await rooms.host.waitForTimeout(1_000);
    }
    for (const room of [rooms.host, rooms.guest]) {
      if (!room.isClosed()) await room.close();
    }
    match.rooms = null;
  }

  /** Off camera: `match` made with Find a partner, entered, started, past its countdown. */
  async function make(match: Match): Promise<Rooms> {
    const hostPerson = people[match.host];
    const guestPerson = people[match.guest];
    await onlyTheChat(guestPerson);
    await onlyTheChat(hostPerson);
    await hostPerson.page.goto(HOME);
    await expect(hostPerson.page.getByTestId("game-home")).toBeVisible();
    await waitForView(hostPerson.page);
    const { address } = await offerSeat(
      hostPerson.page,
      way(hostPerson.page, GAME).getByTestId("game-lfg"),
      match.host,
    );
    const host = await enterRoom(hostPerson.page, hostPerson.ctx, address);
    await expect(seatCard(guestPerson, address)).toBeVisible({
      timeout: 15_000,
    });
    const guest = await enterRoom(guestPerson.page, guestPerson.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, GAME);
    const token = new URL(host.url()).pathname.split("/").pop() as string;
    match.rooms = { host, guest, token };
    match.over = false;
    await host.waitForTimeout(4_000);
    return match.rooms;
  }

  /** Off camera: the friends' match being played — a new one if the last is over. */
  async function friendsPlaying(): Promise<Rooms> {
    if (await on(first)) return first.rooms!;
    await closeSession(first);
    return make(first);
  }

  /** Off camera: Pixel's tab watching the friends' match, in front. */
  async function watching(): Promise<{ watch: Page; rooms: Rooms }> {
    const rooms = await friendsPlaying();
    const pixel = people[PIXEL];
    const at = `/watch/${rooms.token}`;
    let watch = pixel.ctx.pages().find((tab) => tab.url().endsWith(at));
    for (const tab of pixel.ctx.pages()) {
      if (tab !== pixel.page && tab !== watch) await tab.close();
    }
    if (!watch) {
      watch = await pixel.ctx.newPage();
      await watch.goto(at);
    }
    await expect
      .poll(
        async () =>
          Number(await watchCanvas(watch!).getAttribute("data-frames")),
        {
          timeout: 30_000,
        },
      )
      .toBeGreaterThan(0);
    await watch.bringToFront();
    await restCursor(watch);
    return { watch, rooms };
  }

  /** Off camera: the friends' match played to its end — who won kept — its session left open. */
  async function friendsDone(): Promise<void> {
    if (first.over) return;
    if (!first.rooms) await make(first);
    const { host, guest } = first.rooms!;
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: MATCH_TIMEOUT,
      });
    }
    const hostWon =
      (await host.getByTestId("lobby-game-outcome").textContent())?.trim() ===
      "You win!";
    [winner, loser] = hostWon ? [KESTREL, NOVA] : [NOVA, KESTREL];
    second.guest = winner;
    first.over = true;
  }

  /** A scene during `match` must end with it still on. */
  async function stillOn(match: Match, scene: string) {
    if (!(await on(match))) {
      throw new Error(`the match ended during scene ${scene}: retake it`);
    }
  }

  /** Off camera: Pixel's match being played against the winner, the friends' over. */
  async function pixelPlaying(): Promise<Rooms> {
    if (await on(second)) return second.rooms!;
    await friendsDone();
    await closeSession(first);
    await closeSession(second);
    return make(second);
  }

  /** Off camera: the loser's tab watching Pixel's match, in front. */
  async function standsOpen(rooms: Rooms): Promise<Page> {
    const watcher = people[loser];
    const at = `/watch/${rooms.token}`;
    let stands = watcher.ctx.pages().find((tab) => tab.url().endsWith(at));
    if (!stands) {
      await onlyTheChat(watcher);
      stands = await watcher.ctx.newPage();
      await stands.goto(at);
    }
    await expect
      .poll(
        async () =>
          Number(await watchCanvas(stands!).getAttribute("data-frames")),
        {
          timeout: 30_000,
        },
      )
      .toBeGreaterThan(0);
    await stands.bringToFront();
    return stands;
  }

  test("01 something is on", async () => {
    const shot = shotFor(1);
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    const rooms = await friendsPlaying();
    const pixel = people[PIXEL];
    await onlyTheChat(pixel);
    const page = pixel.page;
    await expect(liveLink(channelBar(pixel), rooms.token)).toBeVisible({
      timeout: 15_000,
    });
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(400);
        await focus(liveLink(channelBar(pixel), rooms.token));
        await cue("The game's home has it too");
        await focus(null);
        const home = channelBar(pixel).getByTestId("game-channel-home");
        await pointAt(page, home);
        await home.click();
        await expect(page.getByTestId("game-home")).toBeVisible();
        await waitForView(page);
        await pointAt(page, page.getByTestId("game-home-tab-live"));
        await page.getByTestId("game-home-tab-live").click();
        await restCursor(page);
        await focus(
          liveLink(page.getByTestId("game-community-live"), rooms.token),
        );
        await cue("Nobody needs a seat");
        await focus(page.getByTestId("game-community-live"));
        await stillOn(first, "1");
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 a seat in the stands", async () => {
    const shot = shotFor(2);
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    const rooms = await friendsPlaying();
    await homeOpen("live");
    const pixel = people[PIXEL];
    const page = pixel.page;
    const listed = liveLink(
      page.getByTestId("game-community-live"),
      rooms.token,
    );
    await expect(listed).toBeVisible({ timeout: 15_000 });
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await pace(300);
        await focus(listed);
        await pointAt(page, listed);
        await listed.click();
        const [watch] = await Promise.all([
          pixel.ctx.waitForEvent("page"),
          page.getByTestId("open-tab-confirm-open").click(),
        ]);
        await expect
          .poll(
            async () =>
              Number(await watchCanvas(watch).getAttribute("data-frames")),
            {
              timeout: 20_000,
            },
          )
          .toBeGreaterThan(0);
        await follow(watch);
        await cue("Live, one watching");
        await focus(watch.getByTestId("watch-watchers"));
        await cue("It's the match as the host plays it");
        await focus(watchCanvas(watch));
        await stillOn(first, "2");
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 reading the arena", async () => {
    const shot = shotFor(3);
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    const { watch, rooms } = await watching();
    await restCursor(rooms.host);
    await filmCrew(
      { [PIXEL]: watch, [KESTREL]: rooms.host },
      shot,
      async ({ cue, focus }) => {
        await focus(watchCanvas(watch));
        await cue("Every cell it crosses");
        await focus(matchCanvas(rooms.host, GAME));
        await cue("Hit a wall");
        await focus(watchCanvas(watch));
        await cue("First to three rounds");
        await focus(null);
        await stillOn(first, "3");
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("00 cold open", async () => {
    const shot = shotFor(0);
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    const { watch } = await watching();
    await filmCrew(
      { [PIXEL]: watch },
      shot,
      async ({ cue, focus }) => {
        await focus(watchCanvas(watch));
        await cue("Two friends");
        await focus(watch.getByTestId("watch-window"));
        await cue("This is Light Trails");
        await focus(watchCanvas(watch));
        await stillOn(first, "0");
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("04 match over", async () => {
    const shot = shotFor(4);
    test.setTimeout(MATCH_TIMEOUT * 2 + 4 * 60_000);
    // The match Pixel watches is the one played to the end.
    const { watch } = await watching();
    await friendsDone();
    await expect(watch.getByTestId("watch-result")).toBeVisible({
      timeout: 30_000,
    });
    await watch.waitForTimeout(1_000);
    await filmCrew(
      { [PIXEL]: watch },
      shot,
      async ({ cue, focus }) => {
        await focus(watch.getByTestId("watch-result"));
        await cue("Under it");
        await focus(watch.getByTestId("watch-play"));
        await cue("Pixel has seen enough");
        await focus(watch.getByTestId("watch-idle"));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("05 pixel's turn", async () => {
    const shot = shotFor(5);
    test.setTimeout(MATCH_TIMEOUT * 2 + 4 * 60_000);
    await friendsDone();
    const pixel = people[PIXEL];
    // The watch page, over: the friends' match ended, its rooms closed.
    const at = first.rooms ? `/watch/${first.rooms.token}` : null;
    await closeSession(first);
    await closeSession(second);
    const guestPerson = people[winner];
    await onlyTheChat(guestPerson);
    let watch = at
      ? pixel.ctx.pages().find((tab) => tab.url().endsWith(at))
      : undefined;
    await onlyTheChat(pixel, watch ? [watch] : []);
    // Pixel's chat, behind, already on the home the watch page leads to.
    await pixel.page.goto(HOME);
    await expect(pixel.page.getByTestId("game-home")).toBeVisible();
    await waitForView(pixel.page);
    if (!watch) {
      watch = await pixel.ctx.newPage();
      await watch.goto(HOME);
    }
    await watch.bringToFront();
    await restCursor(watch);
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: watch, [winner]: guestPerson.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        const play = watch!.getByTestId("watch-play");
        if (await play.isVisible()) {
          await focus(play);
          await pointAt(watch!, play);
          await play.click();
          await expect(watch!.getByTestId("game-home")).toBeVisible({
            timeout: 15_000,
          });
          await watch!.waitForTimeout(800);
        }
        await follow(pixel.page);
        await restCursor(pixel.page);
        await focus(way(pixel.page, GAME));
        await cue("Find a partner puts a seat");
        const door = way(pixel.page, GAME).getByTestId("game-lfg");
        await pointAt(pixel.page, door);
        const { card, address } = await offerSeat(pixel.page, door, PIXEL);
        await restCursor(pixel.page);
        await focus(card);
        await pointAt(pixel.page, card.getByTestId("share-message-enter"));
        host = await enterRoom(pixel.page, pixel.ctx, address);
        await follow(host);
        await cue("The winner of that match");
        layout("full", winner);
        await expect(seatCard(guestPerson, address)).toBeVisible({
          timeout: 10_000,
        });
        await focus(seatCard(guestPerson, address));
        await pointAt(guestPerson.page, seatCard(guestPerson, address));
        guest = await enterRoom(guestPerson.page, guestPerson.ctx, address);
        await follow(guest);
        layout("split", PIXEL, winner);
        await cue("Both ready");
        await bothReady(host, guest);
        await restCursor(guest);
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, GAME);
        await restCursor(host);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    const token = new URL(host!.url()).pathname.split("/").pop() as string;
    second.rooms = { host: host!, guest: guest!, token };
    second.over = false;
    if (!watch.isClosed()) await watch.close();
  });

  test("06 the stands turn around", async () => {
    const shot = shotFor(6);
    test.setTimeout(MATCH_TIMEOUT * 3 + 4 * 60_000);
    const rooms = await pixelPlaying();
    const watcher = people[loser];
    await onlyTheChat(watcher);
    const link = liveLink(channelBar(watcher), rooms.token);
    await expect(link).toBeVisible({ timeout: 15_000 });
    await rooms.host.bringToFront();
    await restCursor(rooms.host);
    await watcher.page.bringToFront();
    await filmCrew(
      { [PIXEL]: rooms.host, [loser]: watcher.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        await focus(link);
        await cue("The same line under the topic");
        await pointAt(watcher.page, link);
        await link.click();
        const [stands] = await Promise.all([
          watcher.ctx.waitForEvent("page"),
          watcher.page.getByTestId("open-tab-confirm-open").click(),
        ]);
        await expect
          .poll(
            async () =>
              Number(await watchCanvas(stands).getAttribute("data-frames")),
            {
              timeout: 20_000,
            },
          )
          .toBeGreaterThan(0);
        await follow(stands);
        layout("split", PIXEL, loser);
        await cue("On Pixel's screen");
        await rooms.host.getByTestId("game-stage-menu-key").click();
        await expect(
          rooms.host.getByTestId("lobby-game-watchers"),
        ).toContainText("1 watching", { timeout: 10_000 });
        await focus(rooms.host.getByTestId("lobby-game-watchers"));
        await rooms.host.waitForTimeout(2_500);
        await rooms.host.getByTestId("lobby-game-resume").click();
        await focus(null);
        await stillOn(second, "6");
      },
      { kind: "full", cameras: [loser] },
    );
  });

  test("07 from both sides", async () => {
    const shot = shotFor(7);
    test.setTimeout(MATCH_TIMEOUT * 3 + 4 * 60_000);
    const rooms = await pixelPlaying();
    const stands = await standsOpen(rooms);
    for (const room of [rooms.host, rooms.guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: MATCH_TIMEOUT,
      });
    }
    await expect(stands.getByTestId("watch-result")).toBeVisible({
      timeout: 30_000,
    });
    second.over = true;
    await rooms.host.bringToFront();
    await restCursor(rooms.host);
    await filmCrew(
      { [PIXEL]: rooms.host, [loser]: stands },
      shot,
      async ({ cue, focus }) => {
        await focus(rooms.host.getByTestId("lobby-game-result"));
        await cue("From the channel");
        await focus(stands.getByTestId("watch-result"));
        await cue("Light Trails is free to play");
        await focus(null);
      },
      { kind: "split", cameras: [PIXEL, loser] },
    );
  });
});
