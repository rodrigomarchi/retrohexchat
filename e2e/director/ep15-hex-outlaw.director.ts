/**
 * Director — EP15, "Hex Outlaw: training camp".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/15-hex-outlaw/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-outlaw.spec.ts: N112, N113).
 *
 * A training camp: Pixel walks Hex Outlaw's four streets against the computer,
 * then invites kestrel by name from the game's home to a duel on Ricochet; the
 * duel lands in their private conversation and leaves its result card there.
 * bytebard founds #hex-outlaw and talks in it with lumen and nova; nobody
 * films them.
 *
 * Every duel is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A duel lasts as long as it
 * lasts and either may win: a scene during it ends while it is on, and the
 * verdict waits for it, off camera, and opens on its result.
 *
 * Filmed in the order 6, 7, 0, 8, 1, 2, 3, 4, 5: the duel with kestrel and
 * its result first — a duel against the computer before it would be the
 * player's news in the game's channel and keep the duel's out — and the home
 * and the four training duels last, each from its own tab.
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
  typeOnCamera,
} from "./shots";
import {
  autopilot,
  bothReady,
  enterRoom,
  gameCanvas,
  matchCanvas,
  openTab,
  provisionGameChannel,
  recordMatch,
  stageMenu,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "hex_outlaw";
const DUEL = "hex_outlaw_ricochet";
const CHANNEL = "#hex-outlaw";
const HOME = "/games/hex-outlaw";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const NOVA = "nova";
// Nobody films them: they make the game's channel a room people are in.
const REGULARS = [BYTEBARD, LUMEN, NOVA];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "on ricochet, aim at the sky and let it come down" },
  { by: NOVA, says: "the stagecoach eats every bullet, wait for the gap" },
  { by: LUMEN, says: "no man's land is pure reflexes" },
];

/** How long a duel between two hard gunslingers may take, and some to spare. */
const DUEL_TIMEOUT = 6 * 60_000;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };

test.describe.configure({ mode: "serial" });

test.describe("EP15 Hex Outlaw", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  // The duel on now, and its rooms.
  let duel: Rooms | null = null;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    // bytebard founds the game's channel, by a duel in the ledger.
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

  /** Off camera: `who`'s chat on the private conversation with `other`. */
  async function inTheConversation(who: Person, other: string) {
    await onlyTheChat(who);
    await who.chat.sendMessage(`/query ${other}`);
    await expect(who.chat.chatInput).toHaveAttribute(
      "placeholder",
      new RegExp(other),
    );
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

  const inviteForm = () => pixel.page.getByTestId("game-invite");
  const modePicker = () => inviteForm().locator('select[name="game"]');

  /**
   * Pixel invites kestrel by name from the home, to Ricochet: the chat comes
   * forward on their private conversation with the match's card. Returns the
   * card and the room's address.
   */
  async function invite(
    onCamera: boolean,
  ): Promise<{ card: Locator; address: string }> {
    const wayId = DUEL;
    const enters = pixel.page.getByTestId("share-message-enter");
    const before = await enters.count();
    const field = inviteForm().getByTestId("game-challenge-nickname");
    if (onCamera) {
      await pointAt(pixel.page, modePicker());
      await modePicker().selectOption(wayId);
      await pixel.page.waitForTimeout(600);
      await pointAt(pixel.page, field);
      await field.click();
      await typeOnCamera(field, KESTREL);
      await pointAt(pixel.page, inviteForm().getByTestId("game-challenge"));
    } else {
      await modePicker().selectOption(wayId);
      await field.fill(KESTREL);
    }
    await inviteForm().getByTestId("game-challenge").click();
    await expect(enters).not.toHaveCount(before, { timeout: 15_000 });
    const card = pixel.page
      .locator('[data-testid="share-message-card"]')
      .filter({ has: pixel.page.getByTestId("share-message-enter") })
      .last();
    await expect(card).toBeVisible({ timeout: 15_000 });
    const address = (await card
      .getByTestId("share-message-enter")
      .getAttribute("href")) as string;
    return { card, address };
  }

  /** The same duel's card on kestrel's screen. */
  const kestrelCard = (address: string) =>
    kestrel.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();

  /** The duel's result card in the conversation, on Pixel's chat. */
  const resultCard = () =>
    pixel.page
      .locator('[data-testid^="game-result-card-"]')
      .filter({ hasText: KESTREL })
      .last();

  /** Whether the duel is still being shot out in rooms that are open. */
  async function duelOn(): Promise<boolean> {
    if (!duel || duel.host.isClosed() || duel.guest.isClosed()) return false;
    return !(await duel.host.getByTestId("lobby-game-result").isVisible());
  }

  /** Off camera: both rooms closed, the duel with them. */
  async function closeRooms() {
    if (!duel) return;
    for (const room of [duel.host, duel.guest]) {
      if (!room.isClosed()) await room.close();
    }
    duel = null;
  }

  /** Off camera: the duel on Ricochet invited, entered and started, past its countdown. */
  async function duelStarted(): Promise<Rooms> {
    if (await duelOn()) return duel!;
    await closeRooms();
    await inTheConversation(kestrel, PIXEL);
    await homeOpen();
    const { address } = await invite(false);
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    await expect(kestrelCard(address)).toBeVisible({ timeout: 15_000 });
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, DUEL);
    duel = { host, guest };
    await host.waitForTimeout(6_000);
    return duel;
  }

  /** A duel scene must end with the duel still on. */
  async function stillOn(scene: string) {
    if (!(await duelOn())) {
      throw new Error(`the duel ended during scene ${scene}: retake it`);
    }
  }

  test("06 calling kestrel out", async () => {
    const shot = shotFor(6);
    await closeRooms();
    await inTheConversation(kestrel, PIXEL);
    await homeOpen();
    await inviteForm().scrollIntoViewIfNeeded();
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: pixel.page, [KESTREL]: kestrel.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        await focus(inviteForm());
        await cue("Pixel picks Ricochet");
        const { card, address } = await invite(true);
        await restCursor(pixel.page);
        await cue("The duel lands");
        await focus(card);
        await pointAt(pixel.page, card.getByTestId("share-message-enter"));
        host = await enterRoom(pixel.page, pixel.ctx, address);
        await follow(host);
        await cue("kestrel joins from there");
        layout("full", KESTREL);
        await expect(kestrelCard(address)).toBeVisible({ timeout: 10_000 });
        await focus(kestrelCard(address));
        await cast.say(KESTREL, "see you at noon");
        await pointAt(kestrel.page, kestrelCard(address));
        guest = await enterRoom(kestrel.page, kestrel.ctx, address);
        await follow(guest);
        layout("split", PIXEL, KESTREL);
        await cue("Both ready");
        await bothReady(host, guest);
        await restCursor(guest);
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, DUEL);
        await restCursor(host);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    duel = { host: host!, guest: guest! };
  });

  test("07 bank shots", async () => {
    const shot = shotFor(7);
    const { host, guest } = await duelStarted();
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, DUEL));
        await cue("Every hit freezes the street");
        await focus(matchCanvas(guest, DUEL));
        await cue("Then both gunslingers");
        await focus(matchCanvas(host, DUEL));
        await stillOn("7");
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("00 cold open", async () => {
    const shot = shotFor(0);
    const { host, guest } = await duelStarted();
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, DUEL));
        await cue("Pixel calls kestrel out");
        await focus(matchCanvas(guest, DUEL));
        await cue("But this duel took some training");
        await focus(matchCanvas(host, DUEL));
        await stillOn("0");
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("08 the verdict", async () => {
    const shot = shotFor(8);
    test.setTimeout(DUEL_TIMEOUT + 4 * 60_000);
    // Off camera, the duel is shot out — however long it takes.
    const { host, guest } = await duelStarted();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: DUEL_TIMEOUT,
      });
    }
    await expect(resultCard())
      .toBeVisible({ timeout: 30_000 })
      .catch(async () => {
        await recordMatch(pixel.page.request, DUEL, PIXEL, KESTREL, {
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
        await cue("the result lands in their conversation");
        layout("full", PIXEL);
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await resultCard().scrollIntoViewIfNeeded();
        await restCursor(pixel.page);
        await focus(resultCard());
        await cast.say(KESTREL, "rematch on the stagecoach");
        await cue("Hex Outlaw is free to play");
        await focus(resultCard());
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await closeRooms();
  });

  test("01 four streets", async () => {
    const shot = shotFor(1);
    await closeRooms();
    await homeOpen();
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(400);
        await focus(page.getByTestId("game-ways"));
        await cue("Hex Outlaw itself");
        await focus(way(page, GAME));
        await cue("Ricochet, behind a wall");
        await focus(way(page, "hex_outlaw_ricochet"));
        await cue("Stagecoach, around a coach");
        await focus(way(page, "hex_outlaw_stagecoach"));
        await cue("And No Man's Land");
        await focus(way(page, "hex_outlaw_nml"));
        await cue("Pixel trains on every one");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  /**
   * Scenes 2 to 5: a training duel against the computer on `wayId`, from
   * the street's own tab, opened off camera from the home.
   */
  async function training(scene: number, wayId: string, cues: string[]) {
    const shot = shotFor(scene);
    await homeOpen();
    const game = await openTab(
      pixel.page,
      way(pixel.page, wayId).getByTestId("game-play"),
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
        await focus(gameCanvas(game, wayId));
        for (const line of cues) {
          await cue(line);
          await focus(gameCanvas(game, wayId));
        }
      },
      { kind: "full", cameras: [PIXEL] },
    );
    await game.close();
  }

  test("02 the cactus", async () => {
    await training(2, GAME, ["Line up with your rival", "Ten hits"]);
  });

  test("03 ricochet", async () => {
    await training(3, "hex_outlaw_ricochet", [
      "Press up to aim high",
      "A bullet bounces once",
    ]);
  });

  test("04 stagecoach", async () => {
    await training(4, "hex_outlaw_stagecoach", ["Time your shot"]);
  });

  test("05 no man's land", async () => {
    await training(5, "hex_outlaw_nml", ["Here you can also step"]);
  });
});
