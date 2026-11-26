/**
 * Director — EP14, "Hex Boxing: round by round".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/14-hex-boxing/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-boxing.spec.ts: N93, N110, N111).
 *
 * One fight between Pixel and kestrel, called round by round: Pixel presses
 * Find a partner on Hex Boxing's home, the seat's card goes up in #hex-boxing,
 * kestrel takes it, and the fight is filmed in chapters — round one while it
 * is boxed, round two from its countdown, then the decision, on both screens
 * and on Scoreboard's card in the channel. bytebard founds #hex-boxing and
 * talks in it with lumen and nova; nobody films them.
 *
 * Every fight is really boxed: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. Which round is on is the round
 * the host's autopilot last saw (`matchSeen`). A round lasts until a knockout
 * or its bell and either boxer may win it: a round's scene that outlives its
 * round fails, to be retaken.
 *
 * Filmed in the order 3, 4, 5, 0, 6, 1, 2: the fight is made, round one and
 * round two are filmed while they are boxed, the cold open from whatever
 * round is on next, the decision once the fight is over, and the home and
 * the sparring last — a fight of Pixel's against the computer before the
 * fight with kestrel would keep Scoreboard from announcing that one.
 *
 * Each scene puts, off camera, what it needs in place, so any one of them can
 * be retaken alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { Browser, expect, Page, test } from "@playwright/test";
import { TestUser } from "../helpers/chatUsers";
import { waitForView } from "../helpers/liveView";
import { matchSeen } from "../helpers/retroGames";
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
const GAME = "hex_boxing";
const CHANNEL = "#hex-boxing";
const HOME = "/games/hex-boxing";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const NOVA = "nova";
// Nobody films them: they make the game's channel a room people are in.
const REGULARS = [BYTEBARD, LUMEN, NOVA];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "wait for the glow, then step back" },
  { by: NOVA, says: "up close is three points, worth the risk" },
  { by: LUMEN, says: "anyone up for a fight tonight?" },
];

/** How long a fight between two hard boxers may take, and some to spare. */
const FIGHT_TIMEOUT = 6 * 60_000;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };

test.describe.configure({ mode: "serial" });

test.describe("EP14 Hex Boxing", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  // The fight on now, and its rooms.
  let fight: Rooms | null = null;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    // bytebard founds the game's channel, by a fight in the ledger.
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      GAME,
      BYTEBARD,
      { p1: 2, p2: 1 },
    );
    kestrel = await person(browser, KESTREL, "America/Chicago");
    await autopilot(kestrel.ctx, "hard");
    pixel = await person(browser, PIXEL, "Europe/Lisbon");
    await autopilot(pixel.ctx, "hard");
    cast.adopt(kestrel);
    for (const nick of REGULARS) {
      await inTheChannel(cast.member(nick));
    }
    await cast.play(EARLIER);
  });

  test.afterAll(async () => {
    await cast?.dismiss();
    await pixel?.ctx.close();
  });

  /**
   * Off camera: in a channel at its own address, the way game-channels.spec.ts
   * opens it — the address wins over whatever channel the last session ended
   * in, and keeps winning once the restore has run.
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

  /** Off camera: every tab but the chat closed, the chat in front, in `channel`. */
  async function onlyTheChat(who: Person, channel = "#lobby") {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    await who.page.bringToFront();
    await inTheChannel(who, channel);
    await restCursor(who.page);
  }

  /** Off camera: Pixel's chat with the game's home open over it. */
  async function homeOpen() {
    await onlyTheChat(pixel);
    await pixel.page.goto(HOME);
    await expect(pixel.page.getByTestId("game-home")).toBeVisible();
    await waitForView(pixel.page);
    await pixel.page.waitForTimeout(1000);
    await restCursor(pixel.page);
  }

  const findAPartner = () => way(pixel.page, GAME).getByTestId("game-lfg");

  /** The fight's result card in #hex-boxing, on Pixel's chat. */
  const resultCard = () =>
    pixel.page
      .locator('[data-testid^="game-result-card-"]')
      .filter({ hasText: KESTREL })
      .last();

  /** The same seat's card on kestrel's screen. */
  const kestrelCard = (address: string) =>
    kestrel.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();

  /** Whether the fight is still being boxed in rooms that are open. */
  async function fightOn(): Promise<boolean> {
    if (!fight || fight.host.isClosed() || fight.guest.isClosed()) return false;
    return !(await fight.host.getByTestId("lobby-game-result").isVisible());
  }

  /** Off camera: both rooms closed, the fight with them. */
  async function closeRooms() {
    if (!fight) return;
    for (const room of [fight.host, fight.guest]) {
      if (!room.isClosed()) await room.close();
    }
    fight = null;
  }

  /** Off camera: a fight on, made the way scene 3 makes it, past the countdown. */
  async function fightStarted(): Promise<Rooms> {
    if (await fightOn()) return fight!;
    await closeRooms();
    await onlyTheChat(kestrel, CHANNEL);
    await homeOpen();
    const { address } = await offerSeat(pixel.page, findAPartner(), PIXEL);
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    await expect(kestrelCard(address)).toBeVisible({ timeout: 15_000 });
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, GAME);
    fight = { host, guest };
    await host.waitForTimeout(6_000);
    return fight;
  }

  /** The round the fight is in, as Pixel's seat last saw it. */
  const roundOn = async (rooms: Rooms) =>
    (await matchSeen(rooms.host))?.round ?? 0;

  /** Off camera: a fight in round `round`, from that round's countdown. */
  async function roundBegun(round: number): Promise<Rooms> {
    let rooms = await fightStarted();
    if ((await roundOn(rooms)) > round) {
      // Filmed alone, the fight got past it: box another.
      await closeRooms();
      rooms = await fightStarted();
    }
    await expect
      .poll(() => roundOn(rooms), {
        timeout: FIGHT_TIMEOUT,
        intervals: [100],
      })
      .toBeGreaterThanOrEqual(round);
    if ((await roundOn(rooms)) !== round || !(await fightOn())) {
      throw new Error(`the fight never boxed round ${round}: retake it`);
    }
    return rooms;
  }

  /** A round's scene must end with its round still being boxed. */
  async function stillRound(rooms: Rooms, round: number, scene: string) {
    if ((await roundOn(rooms)) !== round || !(await fightOn())) {
      throw new Error(`round ${round} ended during scene ${scene}: retake it`);
    }
  }

  test("03 making the fight", async () => {
    const shot = shotFor(3);
    await closeRooms();
    await onlyTheChat(kestrel, CHANNEL);
    await homeOpen();
    await findAPartner().scrollIntoViewIfNeeded();
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: pixel.page, [KESTREL]: kestrel.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        await focus(way(pixel.page, GAME));
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
        await cue("kestrel takes the seat");
        layout("full", KESTREL);
        await expect(kestrelCard(address)).toBeVisible({ timeout: 10_000 });
        await focus(kestrelCard(address));
        await cast.say(KESTREL, "I'll take that fight");
        await pointAt(kestrel.page, kestrelCard(address));
        guest = await enterRoom(kestrel.page, kestrel.ctx, address);
        await follow(guest);
        layout("split", PIXEL, KESTREL);
        await cue("Both ready");
        await bothReady(host, guest);
        await restCursor(guest);
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, GAME);
        await restCursor(host);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    fight = { host: host!, guest: guest! };
  });

  /** Scenes 4 and 5: round `round` on both screens, while it is boxed. */
  async function aRound(scene: number, round: number, cues: string[]) {
    const shot = shotFor(scene);
    test.setTimeout(FIGHT_TIMEOUT + 4 * 60_000);
    const rooms = await roundBegun(round);
    const { host, guest } = rooms;
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue(cues[0]);
        await focus(matchCanvas(guest, GAME));
        await cue(cues[1]);
        await focus(matchCanvas(host, GAME));
        await stillRound(rooms, round, String(scene));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  }

  test("04 round one", async () => {
    await aRound(4, 1, ["Pixel in green", "Fill yours to the end"]);
  });

  test("05 round two", async () => {
    await aRound(5, 2, ["That lit dot", "Split them"]);
  });

  test("00 cold open", async () => {
    const shot = shotFor(0);
    const rooms = await fightStarted();
    const { host, guest } = rooms;
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue("In the green corner");
        await focus(matchCanvas(guest, GAME));
        await cue("Here's how this fight was made");
        await focus(matchCanvas(host, GAME));
        if (!(await fightOn())) {
          throw new Error("the fight ended during the cold open: retake it");
        }
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("06 the decision", async () => {
    const shot = shotFor(6);
    test.setTimeout(FIGHT_TIMEOUT + 4 * 60_000);
    // Off camera, the fight is boxed out — however long it takes.
    const { host, guest } = await fightStarted();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: FIGHT_TIMEOUT,
      });
    }
    await expect(resultCard())
      .toBeVisible({ timeout: 30_000 })
      .catch(async () => {
        await recordMatch(pixel.page.request, GAME, PIXEL, KESTREL, {
          p1: 2,
          p2: 1,
        });
        await expect(resultCard()).toBeVisible({ timeout: 15_000 });
      });
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(host.getByTestId("lobby-game-result"));
        await cue("Two rounds take the fight");
        layout("full", PIXEL);
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await resultCard().scrollIntoViewIfNeeded();
        await restCursor(pixel.page);
        await focus(resultCard());
        await cast.say(KESTREL, "rematch next week?");
        await cue("Hex Boxing is free to play");
        await focus(resultCard());
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await closeRooms();
  });

  test("01 the card", async () => {
    const shot = shotFor(1);
    await homeOpen();
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(400);
        await focus(way(page, GAME));
        await cue("Win two rounds");
        await focus(way(page, GAME));
        await cue("find a partner right here");
        await pointAt(page, findAPartner());
        await cue("Pixel spars with the computer");
        await restCursor(page);
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 sparring", async () => {
    const shot = shotFor(2);
    // Filmed last, the chat behind the home already holds the fight: the
    // camera starts on the game's own tab, opened off camera from the home.
    await homeOpen();
    const game = await openTab(
      pixel.page,
      way(pixel.page, GAME).getByTestId("game-play"),
    );
    await expect(game.getByTestId("retro-game-start-ai")).toBeVisible({
      timeout: 15_000,
    });
    await restCursor(game);
    await filmCrew(
      { [PIXEL]: game },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
        const hard = game.getByTestId("retro-game-difficulty-hard");
        await pointAt(game, hard);
        await hard.click();
        await pointAt(game, game.getByTestId("retro-game-start-ai"));
        await game.getByTestId("retro-game-start-ai").click();
        await expect(stageMenu(game)).toBeHidden();
        await restCursor(game);
        await focus(gameCanvas(game, GAME));
        await cue("Land it up close");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
