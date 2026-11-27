/**
 * Director — EP22, "Hex Frost: the steal".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/22-hex-frost/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-frost.spec.ts: N130, N131, N132).
 *
 * The episode is about the steal: Pixel and kestrel play a Blizzard made
 * with Find a partner on the home's Blizzard row, its scenes coming as the
 * round gets there — its start, the igloos growing and being stolen from,
 * the end in a finished igloo or the cold. Then a Peaceful round against the
 * computer, the same ice without stealing. bytebard founds #hex-frost and
 * talks in it with lumen; nobody films them.
 *
 * Every round is really played: each seat's keys are pressed by the game's
 * own computer player (`autopilot`), all at hard. How far the blizzard has
 * gone is read from the host's autopilot (`iceSeen`). A scene during the
 * blizzard fails, to be retaken, if the round ends before it does.
 *
 * Filmed in the order 1, 2, 3, 4, 0, 5, 6, 7: one blizzard from its start to
 * its end — the cold open from the middle of it — then the peaceful round.
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
import { iceSeen } from "../helpers/retroGames";
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
const BLIZZARD = "hex_frost_blizzard";
const CLEAN = "hex_frost_peaceful";
const CHANNEL = "#hex-frost";
const HOME = "/games/hex-frost";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const REGULARS = [BYTEBARD, LUMEN];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "blizzard tonight? bring a warm igloo" },
  { by: LUMEN, says: "land on their blocks, it's the fastest way up" },
];

/** How long a blizzard may take, and some to spare. */
const ROUND_TIMEOUT = 5 * 60_000;
/** Degrees left when the round is near its end by the cold. */
const COLD = 6;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };
/** Where the story stands: no blizzard, one being played, one over. */
type Stage = "none" | "blizzard" | "blizzardOver";

test.describe.configure({ mode: "serial" });

test.describe("EP22 Hex Frost", () => {
  let cast: Cast;
  const people: Record<string, Person> = {};
  let rooms: Rooms | null = null;
  let stage: Stage = "none";

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      "hex_frost",
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
    way(people[PIXEL].page, BLIZZARD).getByTestId("game-lfg");
  const seatCard = (who: Person, address: string) =>
    who.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();
  const result = (room: Page) => room.getByTestId("lobby-game-result");

  /** Whether the blizzard is being played in rooms that are open. */
  async function on(): Promise<boolean> {
    if (!rooms || rooms.host.isClosed() || rooms.guest.isClosed()) return false;
    return !(await result(rooms.host).isVisible());
  }

  /** A scene during the blizzard must end with it still on. */
  async function stillOn(scene: string) {
    if (!(await on())) {
      throw new Error(`the blizzard ended during scene ${scene}: retake it`);
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

  /** Off camera: a blizzard made with Find a partner, entered, started. */
  async function makeBlizzard(): Promise<Rooms> {
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
    await startMatch(host, guest, BLIZZARD);
    rooms = { host, guest };
    stage = "blizzard";
    await host.waitForTimeout(5_000);
    return rooms;
  }

  /**
   * Off camera: the blizzard being played, at least as far as `ready` says —
   * the one on screen, or a new one if that is over.
   */
  async function blizzardAt(
    ready: (seen: { temperature: number; complete: boolean }) => boolean = () =>
      true,
  ): Promise<Rooms> {
    const r =
      stage === "blizzard" && (await on()) ? rooms! : await makeBlizzard();
    await expect
      .poll(
        async () => {
          const seen = await iceSeen(r.host);
          return !!seen && ready(seen);
        },
        { timeout: ROUND_TIMEOUT, intervals: [500] },
      )
      .toBe(true);
    return r;
  }

  /** The shore along the top of a room's game, both igloos on it: in CSS pixels. */
  async function shore(room: Page) {
    const box = (await matchCanvas(room, BLIZZARD).boundingBox())!;
    const k = Math.min(box.width / 640, box.height / 480);
    const x = box.x + (box.width - 640 * k) / 2;
    const y = box.y + (box.height - 480 * k) / 2;
    return { x, y: y + 20 * k, width: 640 * k, height: 110 * k };
  }

  /** Scenes 2, 4 and 0: the blizzard on both screens, while it is played. */
  async function onBothScreens(scene: number, r: Rooms, cues: string[]) {
    const shot = shotFor(scene);
    await r.host.bringToFront();
    await restCursor(r.host);
    await restCursor(r.guest);
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(r.host, BLIZZARD));
        await cue(cues[0]);
        await focus(matchCanvas(r.guest, BLIZZARD));
        await cue(cues[1]);
        await focus(matchCanvas(r.host, BLIZZARD));
        await stillOn(String(scene));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  }

  test("01 a blizzard", async () => {
    const shot = shotFor(1);
    test.setTimeout(ROUND_TIMEOUT + 4 * 60_000);
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
        await cue("Pixel presses Find a partner");
        await focus(way(pixel.page, BLIZZARD));
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
        await startMatch(host, guest, BLIZZARD);
        await restCursor(host);
        await focus(matchCanvas(host, BLIZZARD));
      },
      { kind: "full", cameras: [PIXEL] },
    );
    rooms = { host: host!, guest: guest! };
    stage = "blizzard";
  });

  test("02 building", async () => {
    test.setTimeout(ROUND_TIMEOUT + 4 * 60_000);
    const r = await blizzardAt();
    await onBothScreens(2, r, ["A white block", "Land on one of your own"]);
  });

  test("03 the steal", async () => {
    const shot = shotFor(3);
    test.setTimeout(ROUND_TIMEOUT + 4 * 60_000);
    const r = await blizzardAt();
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focusBox }) => {
        focusBox(r.host, await shore(r.host));
        await cue("Land on it");
        focusBox(r.guest, await shore(r.guest));
        await cue("You gain a piece");
        focusBox(r.host, await shore(r.host));
        await stillOn("3");
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("04 blizzard", async () => {
    test.setTimeout(ROUND_TIMEOUT + 4 * 60_000);
    const r = await blizzardAt();
    await onBothScreens(4, r, [
      "Five lives each",
      "The temperature keeps falling",
    ]);
  });

  test("00 cold open", async () => {
    test.setTimeout(ROUND_TIMEOUT + 4 * 60_000);
    const r = await blizzardAt();
    await onBothScreens(0, r, ["Every block you land on", "This is Hex Frost"]);
  });

  test("05 home before the cold", async () => {
    const shot = shotFor(5);
    test.setTimeout(ROUND_TIMEOUT * 2 + 4 * 60_000);
    // The cold close, or an igloo finished: the round has seconds left, and
    // the take runs its lines, then on to the end.
    const r = await blizzardAt(
      (seen) => seen.temperature <= COLD || seen.complete,
    );
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(r.host, BLIZZARD));
        await cue("If the cold gets there first");
        await cue("Run out of lives");
        for (const room of [r.host, r.guest]) {
          await expect(result(room)).toBeVisible({ timeout: ROUND_TIMEOUT });
        }
        await focus(result(r.host));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    stage = "blizzardOver";
  });

  /** Off camera: the peaceful round's stage, against the computer, its menu up or its round on. */
  let clean: Page | null = null;

  test("06 no stealing", async () => {
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
        await cue("A block in the other colour");
        await startAgainstComputer(clean, { difficulty: "hard" });
        await restCursor(clean);
        await focus(gameCanvas(clean, CLEAN));
        await cue("Best of five rounds");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("07 best of five", async () => {
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
        await cue("Hex Frost is free to play");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
