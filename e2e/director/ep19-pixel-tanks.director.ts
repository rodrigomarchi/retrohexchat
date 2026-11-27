/**
 * Director — EP19, "Pixel Tanks: the rematch".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/19-pixel-tanks/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-pixel-tanks.spec.ts: N121, N122, N123).
 *
 * A match and its rematch: Pixel takes on kestrel in a match made with Find a
 * partner in #pixel-tanks, played to its Final Score; whoever did not win
 * presses Rematch, and the second match is played in the same room: the seat
 * was taken for this game, so nobody is asked again. bytebard founds #pixel-tanks and talks in it with lumen; nobody
 * films them.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), all at hard. A scene during a match fails,
 * to be retaken, if the match ends before it does; the scene after waits for
 * the result off camera.
 *
 * Filmed in the order 1, 2, 3, 4, 5, 6, 0, 7: the first match while it is on
 * and at its end, the rematch asked for, the rematch while it is on — the
 * cold open from it — and at its end.
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
  matchCanvas,
  offerSeat,
  provisionGameChannel,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "pixel_tanks";
const CHANNEL = "#pixel-tanks";
const HOME = "/games/pixel-tanks";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const REGULARS = [BYTEBARD, LUMEN];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "bounce it off the wall, never shoot straight" },
  { by: LUMEN, says: "best of three, and then a rematch, always" },
];

/** How long a match between two hard tanks may take, and some to spare. */
const MATCH_TIMEOUT = 9 * 60_000;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };
/** Where the story stands: the first match, its end, the rematch, its end. */
type Stage = "none" | "first" | "firstOver" | "rematch" | "rematchOver";

test.describe.configure({ mode: "serial" });

test.describe("EP19 Pixel Tanks", () => {
  let cast: Cast;
  const people: Record<string, Person> = {};
  let rooms: Rooms | null = null;
  let stage: Stage = "none";

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      GAME,
      BYTEBARD,
      { p1: 2, p2: 1 },
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
    way(people[PIXEL].page, GAME).getByTestId("game-lfg");
  const seatCard = (who: Person, address: string) =>
    who.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();
  const result = (room: Page) => room.getByTestId("lobby-game-result");

  /** Whether a match is being played in rooms that are open. */
  async function on(): Promise<boolean> {
    if (!rooms || rooms.host.isClosed() || rooms.guest.isClosed()) return false;
    return !(await result(rooms.host).isVisible());
  }

  /** A scene during a match must end with it still on. */
  async function stillOn(scene: string) {
    if (!(await on())) {
      throw new Error(`the match ended during scene ${scene}: retake it`);
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
  }

  /** Off camera: the first match made with Find a partner, entered, started. */
  async function makeFirst(): Promise<Rooms> {
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
    await startMatch(host, guest, GAME);
    rooms = { host, guest };
    stage = "first";
    await host.waitForTimeout(5_000);
    return rooms;
  }

  /** Off camera: the match on screen played to its Final Score on both screens. */
  async function playedOut() {
    for (const room of [rooms!.host, rooms!.guest]) {
      await expect(result(room)).toBeVisible({ timeout: MATCH_TIMEOUT });
    }
    await rooms!.host.waitForTimeout(1_000);
  }

  /** Off camera: the first match over, its Final Score on both screens. */
  async function firstOver(): Promise<Rooms> {
    if (stage === "firstOver") return rooms!;
    if (stage !== "first" || !rooms) await makeFirst();
    await playedOut();
    stage = "firstOver";
    return rooms!;
  }

  /** Who asks for the rematch — whoever did not win; on a draw, the guest. */
  async function askerAndAsked(r: Rooms): Promise<[Page, Page]> {
    const hostWon =
      (await r.host.getByTestId("lobby-game-outcome").textContent())?.trim() ===
      "You win!";
    return hostWon ? [r.guest, r.host] : [r.host, r.guest];
  }

  /** The rematch asked for, and on both screens: the seat was taken for this game, so nobody is asked again. */
  async function rematch(r: Rooms) {
    const [asker] = await askerAndAsked(r);
    await asker.getByTestId("lobby-game-rematch").click();
    for (const room of [r.host, r.guest]) {
      await expect(result(room)).toBeHidden({ timeout: 20_000 });
      await expect(matchCanvas(room, GAME)).toBeVisible({ timeout: 20_000 });
    }
    stage = "rematch";
  }

  /** Off camera: the rematch being played — or, for its end, played already. */
  async function rematchOn(over = false): Promise<Rooms> {
    const open = rooms && !rooms.host.isClosed() && !rooms.guest.isClosed();
    if (stage === "rematch" && open && (over || (await on()))) return rooms!;
    const r = await firstOver();
    await rematch(r);
    await r.host.waitForTimeout(5_000);
    return r;
  }

  /** Scenes 2, 3, 6 and 0: the match on screen, on both screens, while it is played. */
  async function onBothScreens(scene: number, r: Rooms, cues: string[]) {
    const shot = shotFor(scene);
    await r.host.bringToFront();
    await restCursor(r.host);
    await restCursor(r.guest);
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(r.host, GAME));
        await cue(cues[0]);
        await focus(matchCanvas(r.guest, GAME));
        await cue(cues[1]);
        await focus(matchCanvas(r.host, GAME));
        await stillOn(String(scene));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  }

  /** Off camera: the first match being played. */
  async function firstOn(): Promise<Rooms> {
    if (stage === "first" && (await on())) return rooms!;
    return makeFirst();
  }

  test("01 the challenge", async () => {
    const shot = shotFor(1);
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    await closeSession();
    const pixel = people[PIXEL];
    const friend = people[KESTREL];
    await onlyTheChat(friend);
    await homeOpen();
    await findAPartner().scrollIntoViewIfNeeded();
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: pixel.page, [KESTREL]: friend.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        await focus(way(pixel.page, GAME));
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
        await cue("kestrel takes it");
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
        await startMatch(host, guest, GAME);
        await restCursor(host);
        await cue("Best of three rounds");
        await focus(matchCanvas(host, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
    rooms = { host: host!, guest: guest! };
    stage = "first";
  });

  test("02 two tanks", async () => {
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    const r = await firstOn();
    await onBothScreens(2, r, ["Space fires a shell", "Each hit is a point"]);
  });

  test("03 out of sight", async () => {
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    const r = await firstOn();
    await onBothScreens(3, r, [
      "Each one comes back behind a wall",
      "Then the hunt",
    ]);
  });

  test("04 final score", async () => {
    const shot = shotFor(4);
    test.setTimeout(MATCH_TIMEOUT * 2 + 4 * 60_000);
    const r = await firstOver();
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(result(r.host));
        await cue("One of them won it");
        await focus(result(r.guest));
        await cue("The other isn't done yet");
        await focus(null);
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("05 rematch", async () => {
    const shot = shotFor(5);
    test.setTimeout(MATCH_TIMEOUT * 2 + 4 * 60_000);
    const r = await firstOver();
    const [asker] = await askerAndAsked(r);
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await focus(asker.getByTestId("lobby-game-rematch"));
        await cue("It plays the same game again");
        await pointAt(asker, asker.getByTestId("lobby-game-rematch"));
        await rematch(r);
        await restCursor(r.host);
        await restCursor(r.guest);
        await focus(matchCanvas(r.host, GAME));
        await cue("Both screens go straight");
        await focus(matchCanvas(r.guest, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("06 round two of the rivalry", async () => {
    test.setTimeout(MATCH_TIMEOUT * 3 + 4 * 60_000);
    const r = await rematchOn();
    await onBothScreens(6, r, [
      "The connection between the two browsers",
      "And this time",
    ]);
  });

  test("00 cold open", async () => {
    test.setTimeout(MATCH_TIMEOUT * 3 + 4 * 60_000);
    const r = await rematchOn();
    await onBothScreens(0, r, ["This is the rematch", "Two tanks"]);
  });

  test("07 settled", async () => {
    const shot = shotFor(7);
    test.setTimeout(MATCH_TIMEOUT * 3 + 4 * 60_000);
    const r = await rematchOn(true);
    await playedOut();
    stage = "rematchOver";
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(result(r.host));
        await cue("Settled, or one more");
        await focus(result(r.guest));
        await cue("Pixel Tanks is free to play");
        await focus(null);
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });
});
