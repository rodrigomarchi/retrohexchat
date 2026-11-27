/**
 * Director — EP21, "Hex Skiing: the avalanche".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/21-hex-skiing/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-skiing.spec.ts: N127, N128, N129).
 *
 * The episode follows the avalanche: Pixel and kestrel ski an Escape made
 * with Find a partner on the home's Escape row, and its scenes come as the
 * descent gets there — its start, the bar filling, the stretch where the
 * slope grows thicker, the front on screen, the end. Then a Clean Run against
 * the computer, the same mountain without it. bytebard founds #hex-skiing and
 * talks in it with lumen; nobody films them.
 *
 * Every descent is really skied: each seat's keys are pressed by the game's
 * own computer player (`autopilot`), all at hard. How far the escape has gone
 * is read from the host's autopilot (`slopeSeen`). A scene during the escape
 * fails, to be retaken, if the escape ends before it does.
 *
 * Filmed in the order 0, 1, 2, 3, 4, 5, 6, 7: the cold open from an escape
 * of its own (the front is on screen only for its last seconds), then one
 * escape from its start to its end — the slope thickening, the bar filling,
 * the avalanche catching them — then the clean run.
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
import { slopeSeen } from "../helpers/retroGames";
import {
  autopilot,
  bothReady,
  enterRoom,
  gameCanvas,
  matchCanvas,
  offerSeat,
  playFromHome,
  provisionGameChannel,
  startAgainstComputer,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const ESCAPE = "hex_skiing_escape";
const CLEAN = "hex_skiing_clean";
const CHANNEL = "#hex-skiing";
const HOME = "/games/hex-skiing";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const REGULARS = [BYTEBARD, LUMEN];

const EARLIER: Line[] = [
  {
    by: BYTEBARD,
    says: "sprint first, then we'll see who can drive in the dark",
  },
  { by: LUMEN, says: "turbo only on an empty lane, trust me" },
];

/** How long an escape may take before the avalanche ends it, and some to spare. */
const ESCAPE_TIMEOUT = 6 * 60_000;
/** Where the slope grows thicker, and where the avalanche's front is on screen. */
const THICKER_AT = 18_000;
// The avalanche bar fills from three screens above the view; the front comes
// into view only seconds before the end.
const BAR_RISING = -900;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };
/** Where the story stands: no escape, one being skied, one over. */
type Stage = "none" | "escape" | "escapeOver";

test.describe.configure({ mode: "serial" });

test.describe("EP21 Hex Skiing", () => {
  let cast: Cast;
  const people: Record<string, Person> = {};
  let rooms: Rooms | null = null;
  let stage: Stage = "none";

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      "hex_skiing",
      BYTEBARD,
      { p1: 1, p2: 0 },
    );
    const zones: Record<string, string> = {
      [PIXEL]: "Europe/Lisbon",
      [KESTREL]: "America/Chicago",
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

  /** Off camera: Pixel's chat with the game's home open over it. */
  async function homeOpen() {
    const pixel = people[PIXEL];
    await onlyTheChat(pixel);
    await pixel.page.goto(HOME);
    await expect(pixel.page.getByTestId("game-home")).toBeVisible();
    await waitForView(pixel.page);
    await pixel.page.waitForTimeout(1000);
    await restCursor(pixel.page);
  }

  const findAPartner = () =>
    way(people[PIXEL].page, ESCAPE).getByTestId("game-lfg");
  const seatCard = (who: Person, address: string) =>
    who.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();
  const result = (room: Page) => room.getByTestId("lobby-game-result");

  /** Whether the escape is being skied in rooms that are open. */
  async function on(): Promise<boolean> {
    if (!rooms || rooms.host.isClosed() || rooms.guest.isClosed()) return false;
    return !(await result(rooms.host).isVisible());
  }

  /** A scene during the escape must end with it still on. */
  async function stillOn(scene: string) {
    if (!(await on())) {
      throw new Error(`the escape ended during scene ${scene}: retake it`);
    }
  }

  /** Off camera: the session ended and its rooms closed. */
  async function closeSession() {
    if (!rooms) return;
    if (!rooms.host.isClosed()) {
      await rooms.host.getByTestId("p2p-console-end-session").click();
      await rooms.host.getByTestId("p2p-confirm-dialog-confirm").click();
      await rooms.host.waitForTimeout(1_000);
    }
    for (const room of [rooms.host, rooms.guest]) {
      if (!room.isClosed()) await room.close();
    }
    rooms = null;
    stage = "none";
  }

  /** Off camera: an escape made with Find a partner, entered, started. */
  async function makeEscape(): Promise<Rooms> {
    await closeSession();
    const pixel = people[PIXEL];
    const friend = people[KESTREL];
    await onlyTheChat(friend);
    await homeOpen();
    const { address } = await offerSeat(pixel.page, findAPartner(), PIXEL);
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    await expect(seatCard(friend, address)).toBeVisible({ timeout: 15_000 });
    const guest = await enterRoom(friend.page, friend.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, ESCAPE);
    rooms = { host, guest };
    stage = "escape";
    await host.waitForTimeout(5_000);
    return rooms;
  }

  /**
   * Off camera: the escape being skied, at least as far as `ready` says —
   * the one on screen, or a new one if that is over.
   */
  async function escapeAt(
    ready: (seen: { distance: number; avalancheY: number }) => boolean = () =>
      true,
  ): Promise<Rooms> {
    const r = stage === "escape" && (await on()) ? rooms! : await makeEscape();
    await expect
      .poll(
        async () => {
          const seen = await slopeSeen(r.host);
          return !!seen && ready(seen);
        },
        { timeout: ESCAPE_TIMEOUT, intervals: [500] },
      )
      .toBe(true);
    return r;
  }

  /** The bar at the bottom left of a room's game: the avalanche's, in CSS pixels. */
  async function avalancheBar(room: Page) {
    const box = (await matchCanvas(room, ESCAPE).boundingBox())!;
    const k = Math.min(box.width / 640, box.height / 480);
    const x = box.x + (box.width - 640 * k) / 2;
    const y = box.y + (box.height - 480 * k) / 2;
    return { x, y: y + 400 * k, width: 260 * k, height: 80 * k };
  }

  /** Scenes 2, 4 and 0: the escape on both screens, while it is skied. */
  async function onBothScreens(scene: number, r: Rooms, cues: string[]) {
    const shot = shotFor(scene);
    await r.host.bringToFront();
    await restCursor(r.host);
    await restCursor(r.guest);
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(r.host, ESCAPE));
        await cue(cues[0]);
        await focus(matchCanvas(r.guest, ESCAPE));
        await cue(cues[1]);
        await focus(matchCanvas(r.host, ESCAPE));
        await stillOn(String(scene));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  }

  test("00 cold open", async () => {
    const shot = shotFor(0);
    test.setTimeout(ESCAPE_TIMEOUT + 4 * 60_000);
    // An escape of its own: the front comes into view seconds before the end,
    // and the cold open runs over those seconds to the end.
    await closeSession();
    const r = await escapeAt((seen) => seen.avalancheY >= 0);
    await r.host.bringToFront();
    await restCursor(r.host);
    await restCursor(r.guest);
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(r.host, ESCAPE));
        await cue("It started slower");
        await cue("This is Hex Skiing");
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await closeSession();
  });

  test("01 no finish line", async () => {
    const shot = shotFor(1);
    test.setTimeout(ESCAPE_TIMEOUT + 4 * 60_000);
    await closeSession();
    const pixel = people[PIXEL];
    const friend = people[KESTREL];
    await onlyTheChat(friend);
    await homeOpen();
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: pixel.page, [KESTREL]: friend.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        await focus(pixel.page.getByTestId("game-ways"));
        await cue("Escape is the one");
        await focus(way(pixel.page, ESCAPE));
        await cue("Pixel presses Find a partner");
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
        layout("full", KESTREL);
        await expect(seatCard(friend, address)).toBeVisible({
          timeout: 10_000,
        });
        await focus(seatCard(friend, address));
        await pointAt(friend.page, seatCard(friend, address));
        guest = await enterRoom(friend.page, friend.ctx, address);
        await follow(guest);
        layout("split", PIXEL, KESTREL);
        await cue("Both ready");
        await bothReady(host, guest);
        await restCursor(guest);
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, ESCAPE);
        await restCursor(host);
        await focus(matchCanvas(host, ESCAPE));
      },
      { kind: "full", cameras: [PIXEL] },
    );
    rooms = { host: host!, guest: guest! };
    stage = "escape";
  });

  test("02 downhill", async () => {
    test.setTimeout(ESCAPE_TIMEOUT + 4 * 60_000);
    const r = await escapeAt();
    await onBothScreens(2, r, ["Steering slows you down", "Hit a tree"]);
  });

  test("03 thicker", async () => {
    test.setTimeout(ESCAPE_TIMEOUT + 4 * 60_000);
    const r = await escapeAt((seen) => seen.distance >= THICKER_AT);
    await onBothScreens(3, r, ["More trees, then rocks", "A boost"]);
  });

  test("04 the bar", async () => {
    const shot = shotFor(4);
    test.setTimeout(ESCAPE_TIMEOUT + 4 * 60_000);
    const r = await escapeAt((seen) => seen.avalancheY >= BAR_RISING);
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus, focusBox }) => {
        await focus(matchCanvas(r.host, ESCAPE));
        await cue("Every fifteen seconds");
        await focus(matchCanvas(r.guest, ESCAPE));
        await cue("The bar at the bottom left");
        focusBox(r.host, await avalancheBar(r.host));
        await r.host.waitForTimeout(1_500);
        await stillOn("4");
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("05 caught", async () => {
    const shot = shotFor(5);
    test.setTimeout(ESCAPE_TIMEOUT * 2 + 4 * 60_000);
    // The front on screen: the escape has seconds left, and the take runs
    // its lines, then on to the end.
    const r = await escapeAt((seen) => seen.avalancheY >= 40);
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(r.host, ESCAPE));
        await cue("A skier knocked down");
        await cue("If it takes them both");
        for (const room of [r.host, r.guest]) {
          await expect(result(room)).toBeVisible({ timeout: ESCAPE_TIMEOUT });
        }
        await focus(result(r.host));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    stage = "escapeOver";
  });

  /** Off camera: the clean run's stage, against the computer, its menu up or its run on. */
  let clean: Page | null = null;

  test("06 the same mountain, without it", async () => {
    const shot = shotFor(6);
    test.setTimeout(4 * 60_000);
    await closeSession();
    await homeOpen();
    const page = people[PIXEL].page;
    await way(page, CLEAN).scrollIntoViewIfNeeded();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await pace(300);
        await focus(way(page, CLEAN));
        await pointAt(page, way(page, CLEAN).getByTestId("game-play"));
        clean = await playFromHome(page, CLEAN);
        await follow(clean);
        await cue("No avalanche, no ice");
        await startAgainstComputer(clean, { difficulty: "hard" });
        await restCursor(clean);
        await focus(gameCanvas(clean, CLEAN));
        await cue("Every gate you pass");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("07 best of three", async () => {
    const shot = shotFor(7);
    test.setTimeout(4 * 60_000);
    if (!clean || clean.isClosed()) {
      await homeOpen();
      clean = await playFromHome(people[PIXEL].page, CLEAN);
      await startAgainstComputer(clean, { difficulty: "hard" });
      await clean.waitForTimeout(8_000);
    }
    await clean.bringToFront();
    await restCursor(clean);
    await filmCrew(
      { [PIXEL]: clean },
      shot,
      async ({ cue, focus }) => {
        await focus(gameCanvas(clean!, CLEAN));
        await cue("Hex Skiing is free to play");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
