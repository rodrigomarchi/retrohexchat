/**
 * Director — EP20, "Hex Enduro: a double header".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/20-hex-enduro/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-enduro.spec.ts: N124, N125, N126).
 *
 * Two races on one connection: Pixel and kestrel race a Sprint made with Find
 * a partner on the home's Sprint row, to its Final Score; in the same session
 * Pixel goes Back to games and proposes a Night Race, kestrel is asked and
 * accepts, and the night race runs in the same room. bytebard founds
 * #hex-enduro and talks in it with lumen; nobody films them.
 *
 * Every race is really driven: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), all at hard. A scene during a race fails, to
 * be retaken, if the race ends before it does; the scene after waits for the
 * result off camera.
 *
 * Filmed in the order 1, 2, 3, 4, 5, 6, 0, 7: the Sprint while it is on and
 * at its end, the Night Race proposed and accepted, the Night Race while it is
 * on — the cold open from it — and at its end.
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
const SPRINT = "hex_enduro_sprint";
const NIGHT = "hex_enduro_night";
const CHANNEL = "#hex-enduro";
const HOME = "/games/hex-enduro";

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

/** How long a Sprint may take, and some to spare; a Night Race is three minutes. */
const SPRINT_TIMEOUT = 3 * 60_000;
const NIGHT_TIMEOUT = 5 * 60_000;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };
/** Where the story stands: the Sprint, its end, the Night Race asked for, run, ended. */
type Stage = "none" | "sprint" | "sprintOver" | "asked" | "night" | "nightOver";

test.describe.configure({ mode: "serial" });

test.describe("EP20 Hex Enduro", () => {
  let cast: Cast;
  const people: Record<string, Person> = {};
  let rooms: Rooms | null = null;
  let stage: Stage = "none";

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      "hex_enduro",
      BYTEBARD,
      { p1: 40, p2: 31 },
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
    way(people[PIXEL].page, SPRINT).getByTestId("game-lfg");
  const seatCard = (who: Person, address: string) =>
    who.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();
  const result = (room: Page) => room.getByTestId("lobby-game-result");
  const consent = (room: Page) => room.getByTestId("lobby-game-consent");
  const nightPick = (room: Page) => room.getByTestId(`lobby-game-${NIGHT}`);

  /** Whether a race is being run in rooms that are open. */
  async function on(): Promise<boolean> {
    if (!rooms || rooms.host.isClosed() || rooms.guest.isClosed()) return false;
    return !(await result(rooms.host).isVisible());
  }

  /** A scene during a race must end with it still on. */
  async function stillOn(scene: string) {
    if (!(await on())) {
      throw new Error(`the race ended during scene ${scene}: retake it`);
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

  /** Off camera: the Sprint made with Find a partner, entered, started. */
  async function makeSprint(): Promise<Rooms> {
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
    await startMatch(host, guest, SPRINT);
    rooms = { host, guest };
    stage = "sprint";
    await host.waitForTimeout(5_000);
    return rooms;
  }

  /** Off camera: the race on screen run to its Final Score on both screens. */
  async function playedOut(timeout: number) {
    for (const room of [rooms!.host, rooms!.guest]) {
      await expect(result(room)).toBeVisible({ timeout });
    }
    await rooms!.host.waitForTimeout(1_000);
  }

  /** Off camera: the Sprint being run. */
  async function sprintOn(): Promise<Rooms> {
    if (stage === "sprint" && (await on())) return rooms!;
    return makeSprint();
  }

  /** Off camera: the Sprint over, its Final Score on both screens. */
  async function sprintOver(): Promise<Rooms> {
    if (stage === "sprintOver") return rooms!;
    if (stage !== "sprint" || !rooms) await makeSprint();
    await playedOut(SPRINT_TIMEOUT);
    stage = "sprintOver";
    return rooms!;
  }

  /** Back to games, and the Night Race picked: the friend is asked. */
  async function propose(r: Rooms) {
    await r.host.getByTestId("lobby-game-back").click();
    await expect(nightPick(r.host)).toBeVisible({ timeout: 15_000 });
    await nightPick(r.host).click();
    await expect(consent(r.guest)).toBeVisible({ timeout: 15_000 });
    stage = "asked";
  }

  /** Off camera: the Night Race proposed, the friend's question on screen. */
  async function asked(): Promise<Rooms> {
    if (stage === "asked" && rooms) return rooms;
    const r = await sprintOver();
    await propose(r);
    return r;
  }

  /** Accept: the Night Race on both screens. */
  async function accept(r: Rooms) {
    await consent(r.guest).getByTestId("lobby-game-accept").click();
    for (const room of [r.host, r.guest]) {
      await expect(matchCanvas(room, NIGHT)).toBeVisible({ timeout: 20_000 });
    }
    stage = "night";
  }

  /** Off camera: the Night Race being run — or, for its end, run already. */
  async function nightOn(over = false): Promise<Rooms> {
    const open = rooms && !rooms.host.isClosed() && !rooms.guest.isClosed();
    if (stage === "night" && open && (over || (await on()))) return rooms!;
    const r = await asked();
    await accept(r);
    await r.host.waitForTimeout(5_000);
    return r;
  }

  /** Scenes 2, 6 and 0: the race on both screens, while it is run. */
  async function onBothScreens(
    scene: number,
    r: Rooms,
    wayId: string,
    cues: string[],
  ) {
    const shot = shotFor(scene);
    await r.host.bringToFront();
    await restCursor(r.host);
    await restCursor(r.guest);
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(r.host, wayId));
        await cue(cues[0]);
        await focus(matchCanvas(r.guest, wayId));
        await cue(cues[1]);
        await focus(matchCanvas(r.host, wayId));
        await stillOn(String(scene));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  }

  /** Scenes 3 and 7: the race's Final Score on both screens. */
  async function finalScores(scene: number, r: Rooms, cues: string[]) {
    const shot = shotFor(scene);
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus }) => {
        await focus(result(r.host));
        await cue(cues[0]);
        await focus(result(r.guest));
        await cue(cues[1]);
        await focus(null);
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  }

  test("01 a sprint", async () => {
    const shot = shotFor(1);
    test.setTimeout(SPRINT_TIMEOUT + 4 * 60_000);
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
        await focus(way(pixel.page, SPRINT));
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
        await startMatch(host, guest, SPRINT);
        await restCursor(host);
        await focus(matchCanvas(host, SPRINT));
      },
      { kind: "full", cameras: [PIXEL] },
    );
    rooms = { host: host!, guest: guest! };
    stage = "sprint";
  });

  test("02 ninety seconds", async () => {
    test.setTimeout(SPRINT_TIMEOUT + 4 * 60_000);
    const r = await sprintOn();
    await onBothScreens(2, r, SPRINT, [
      "Space fires a turbo",
      "In a Sprint there's no fuel",
    ]);
  });

  test("03 finish line", async () => {
    test.setTimeout(SPRINT_TIMEOUT * 2 + 4 * 60_000);
    const r = await sprintOver();
    await finalScores(3, r, [
      "The session is still open",
      "One race is a sample",
    ]);
  });

  test("04 another race", async () => {
    const shot = shotFor(4);
    test.setTimeout(SPRINT_TIMEOUT * 2 + 4 * 60_000);
    const r = await sprintOver();
    await r.host.bringToFront();
    await filmCrew(
      { [PIXEL]: r.host },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await focus(r.host.getByTestId("lobby-game-back"));
        await pointAt(r.host, r.host.getByTestId("lobby-game-back"));
        await r.host.getByTestId("lobby-game-back").click();
        await expect(nightPick(r.host)).toBeVisible({ timeout: 15_000 });
        await restCursor(r.host);
        await focus(r.host.getByTestId("p2p-games-catalog"));
        await cue("Pixel picks the Night Race");
        await focus(nightPick(r.host));
        await pointAt(r.host, nightPick(r.host));
        await nightPick(r.host).click();
        await expect(consent(r.guest)).toBeVisible({ timeout: 15_000 });
        await restCursor(r.host);
        await cue("A different race isn't started");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    stage = "asked";
  });

  test("05 asked", async () => {
    const shot = shotFor(5);
    test.setTimeout(SPRINT_TIMEOUT * 2 + 4 * 60_000);
    const r = await asked();
    await r.guest.bringToFront();
    await restCursor(r.guest);
    await filmCrew(
      { [PIXEL]: r.host, [KESTREL]: r.guest },
      shot,
      async ({ cue, focus, layout, pace }) => {
        await pace(300);
        await focus(consent(r.guest));
        await cue("Pixel wants to play");
        await focus(consent(r.guest));
        await cue("Accept, and the lights go out");
        await pointAt(
          r.guest,
          consent(r.guest).getByTestId("lobby-game-accept"),
        );
        await accept(r);
        await restCursor(r.guest);
        layout("split", PIXEL, KESTREL);
        await focus(matchCanvas(r.host, NIGHT));
      },
      { kind: "full", cameras: [KESTREL] },
    );
  });

  test("06 in the dark", async () => {
    test.setTimeout(NIGHT_TIMEOUT + SPRINT_TIMEOUT + 4 * 60_000);
    const r = await nightOn();
    await onBothScreens(6, r, NIGHT, ["No sunrise", "Three minutes"]);
  });

  test("00 cold open", async () => {
    test.setTimeout(NIGHT_TIMEOUT + SPRINT_TIMEOUT + 4 * 60_000);
    const r = await nightOn();
    await onBothScreens(0, r, NIGHT, [
      "This is the second race",
      "The first one was in daylight",
    ]);
  });

  test("07 two results", async () => {
    test.setTimeout(NIGHT_TIMEOUT * 2 + SPRINT_TIMEOUT + 4 * 60_000);
    const r = await nightOn(true);
    await playedOut(NIGHT_TIMEOUT);
    stage = "nightOver";
    await finalScores(7, r, [
      "Two races, two kinds of road",
      "Hex Enduro is free to play",
    ]);
  });
});
