/**
 * Director — EP17, "Hex Hockey: climbing the ranking".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/17-hex-hockey/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-hockey.spec.ts: N116, N117).
 *
 * Pixel climbs the game's ranking: no rating to start with, then two Blitz
 * matches made with Find a partner on the home's Blitz row — kestrel, then
 * nova, taking the seat in #hex-hockey — and the home's Ranking tab read
 * after each. bytebard founds #hex-hockey and talks in it with lumen; nobody
 * films them.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), all at hard. A scene during a match fails,
 * to be retaken, if the match ends before it does; the scene after waits for
 * the result off camera.
 *
 * Filmed in the order 1, 2, 3, 4, 5, 6, 0, 7: the home and the empty rating
 * before any match, each match while it is played, the list after the first,
 * the cold open from the second, and the new place once it is over.
 *
 * Each scene puts, off camera, what it needs in place — the matches before it
 * played out — so any one of them can be retaken alone.
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
  matchCanvas,
  offerSeat,
  provisionGameChannel,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "hex_hockey";
const WAY = "hex_hockey_blitz";
const CHANNEL = "#hex-hockey";
const HOME = "/games/hex-hockey";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const NOVA = "nova";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const REGULARS = [BYTEBARD, LUMEN];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "blitz tonight? the puck is fast in that one" },
  { by: LUMEN, says: "watch the goalies, they read everything now" },
];

/** How long a Blitz match between two hard skaters may take, and some to spare. */
const MATCH_TIMEOUT = 7 * 60_000;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };
type Match = { guest: string; rooms: Rooms | null; over: boolean };

test.describe.configure({ mode: "serial" });

test.describe("EP17 Hex Hockey", () => {
  let cast: Cast;
  const people: Record<string, Person> = {};
  const matches: Match[] = [
    { guest: KESTREL, rooms: null, over: false },
    { guest: NOVA, rooms: null, over: false },
  ];

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    // bytebard founds the game's channel, by a match in the ledger.
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
  async function onlyTheChat(who: Person) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    await who.page.bringToFront();
    await inTheChannel(who);
    await restCursor(who.page);
  }

  /** Off camera: Pixel's chat with the game's home open over it, on `tab`. */
  async function homeOpen(tab: "play" | "ranking" | "you" = "play") {
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

  const findAPartner = () =>
    way(people[PIXEL].page, WAY).getByTestId("game-lfg");
  const ratings = () =>
    people[PIXEL].page.getByTestId("game-community-ratings");
  const seatCard = (who: Person, address: string) =>
    who.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();

  /** Whether `match` is being played in rooms that are open. */
  async function on(match: Match): Promise<boolean> {
    const rooms = match.rooms;
    if (!rooms || rooms.host.isClosed() || rooms.guest.isClosed()) return false;
    return !(await rooms.host.getByTestId("lobby-game-result").isVisible());
  }

  /** Off camera: `match` made with Find a partner, entered, started, past its countdown. */
  async function make(match: Match): Promise<Rooms> {
    const pixel = people[PIXEL];
    const guestPerson = people[match.guest];
    await onlyTheChat(guestPerson);
    await homeOpen();
    const { address } = await offerSeat(pixel.page, findAPartner(), PIXEL);
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    await expect(seatCard(guestPerson, address)).toBeVisible({
      timeout: 15_000,
    });
    const guest = await enterRoom(guestPerson.page, guestPerson.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, WAY);
    match.rooms = { host, guest };
    await host.waitForTimeout(5_000);
    return match.rooms;
  }

  /** Off camera: `match` played out — however long it takes — and its rooms closed. */
  async function playedOut(match: Match) {
    if (match.over) return;
    if (!match.rooms) await make(match);
    const { host, guest } = match.rooms!;
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: MATCH_TIMEOUT,
      });
    }
    await host.getByTestId("p2p-console-end-session").click();
    await host.getByTestId("p2p-confirm-dialog-confirm").click();
    await host.waitForTimeout(1_000);
    for (const room of [host, guest]) if (!room.isClosed()) await room.close();
    match.rooms = null;
    match.over = true;
  }

  /** Off camera: `match` being played, the one before it over. */
  async function playing(index: number): Promise<Rooms> {
    const match = matches[index];
    if (await on(match)) return match.rooms!;
    for (const earlier of matches.slice(0, index)) await playedOut(earlier);
    match.over = false;
    return make(match);
  }

  /** A scene during `match` must end with it still on. */
  async function stillOn(match: Match, scene: string) {
    if (!(await on(match))) {
      throw new Error(`the match ended during scene ${scene}: retake it`);
    }
  }

  /** Scenes 3 and 6: match `index` made on camera — Find a partner, Join, Ready, Start. */
  async function madeOnCamera(scene: number, index: number, cues: string[]) {
    const shot = shotFor(scene);
    test.setTimeout(MATCH_TIMEOUT * 2 + 4 * 60_000);
    const match = matches[index];
    for (const earlier of matches.slice(0, index)) await playedOut(earlier);
    const pixel = people[PIXEL];
    const guestPerson = people[match.guest];
    await onlyTheChat(guestPerson);
    await homeOpen();
    await findAPartner().scrollIntoViewIfNeeded();
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: pixel.page, [match.guest]: guestPerson.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        await focus(way(pixel.page, WAY));
        await cue(cues[0]);
        await pointAt(pixel.page, findAPartner());
        const { card, address } = await offerSeat(
          pixel.page,
          findAPartner(),
          PIXEL,
        );
        await restCursor(pixel.page);
        await focus(card);
        await pointAt(pixel.page, card.getByTestId("share-message-enter"));
        host = await enterRoom(pixel.page, pixel.ctx, address);
        await follow(host);
        await cue(cues[1]);
        layout("full", match.guest);
        await expect(seatCard(guestPerson, address)).toBeVisible({
          timeout: 10_000,
        });
        await focus(seatCard(guestPerson, address));
        await pointAt(guestPerson.page, seatCard(guestPerson, address));
        guest = await enterRoom(guestPerson.page, guestPerson.ctx, address);
        await follow(guest);
        layout("split", PIXEL, match.guest);
        await cue(cues[2]);
        await bothReady(host, guest);
        await restCursor(guest);
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, WAY);
        await restCursor(host);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    match.rooms = { host: host!, guest: guest! };
    match.over = false;
  }

  /** Scenes 4 and 0: match `index` on both screens, while it is played. */
  async function onIce(scene: number, index: number, cues: string[]) {
    const shot = shotFor(scene);
    test.setTimeout(MATCH_TIMEOUT * 2 + 4 * 60_000);
    const match = matches[index];
    const { host, guest } = await playing(index);
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [match.guest]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, WAY));
        await cue(cues[0]);
        await focus(matchCanvas(guest, WAY));
        await cue(cues[1]);
        await focus(matchCanvas(host, WAY));
        await stillOn(match, String(scene));
      },
      { kind: "split", cameras: [PIXEL, match.guest] },
    );
  }

  test("01 three formats", async () => {
    const shot = shotFor(1);
    const page = people[PIXEL].page;
    await homeOpen();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(400);
        await focus(page.getByTestId("game-ways"));
        await cue("Hex Hockey itself");
        await focus(way(page, GAME));
        await cue("Blitz is one period");
        await focus(way(page, WAY));
        await cue("Showdown has no clock");
        await focus(way(page, "hex_hockey_showdown"));
        await cue("All three count");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 no rating yet", async () => {
    const shot = shotFor(2);
    const page = people[PIXEL].page;
    await homeOpen("ranking");
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await focus(page.getByTestId("game-home-ranking"));
        await cue("The rating only counts");
        await pointAt(page, page.getByTestId("game-home-tab-you"));
        await page.getByTestId("game-home-tab-you").click();
        await restCursor(page);
        await cue("Everybody starts");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 match one", async () => {
    await madeOnCamera(3, 0, [
      "Pixel presses Find a partner",
      "kestrel takes it",
      "Both ready",
    ]);
  });

  test("04 on the ice", async () => {
    await onIce(4, 0, ["Space shoots", "The goalie reads"]);
  });

  test("05 on the list", async () => {
    const shot = shotFor(5);
    test.setTimeout(MATCH_TIMEOUT * 2 + 4 * 60_000);
    await playedOut(matches[0]);
    await homeOpen("ranking");
    const page = people[PIXEL].page;
    await expect(ratings()).toContainText(PIXEL);
    await expect(ratings()).toContainText(KESTREL);
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus }) => {
        await focus(ratings());
        await cue("A win takes points");
        await focus(ratings());
        await cue("One of them is above");
        await focus(ratings());
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("06 match two", async () => {
    await madeOnCamera(6, 1, [
      "Same row, same button",
      "A win against somebody",
      "Both ready",
    ]);
  });

  test("00 cold open", async () => {
    await onIce(0, 1, ["Two Blitz matches", "This is the second"]);
  });

  test("07 a new place", async () => {
    const shot = shotFor(7);
    test.setTimeout(MATCH_TIMEOUT * 3 + 4 * 60_000);
    await playedOut(matches[0]);
    await playedOut(matches[1]);
    await homeOpen("ranking");
    const page = people[PIXEL].page;
    await expect(ratings()).toContainText(NOVA);
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus }) => {
        await focus(ratings());
        await cue("Pixel's own tab");
        await pointAt(page, page.getByTestId("game-home-tab-you"));
        await page.getByTestId("game-home-tab-you").click();
        await restCursor(page);
        await focus(page.getByTestId("game-you-rating"));
        await cue("Hex Hockey is free to play");
        await focus(page.getByTestId("game-you-rating"));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
