/**
 * Director — EP13, "Hex Raid: best of three".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/13-hex-raid/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-raid.spec.ts: N108, N109).
 *
 * The episode is a best of three: Pixel invites kestrel by name from the
 * game's home once in each way to fly — Pacifist, Blitz, then Hex Raid — and
 * every match leaves its result card in their private conversation. bytebard
 * founds #hex-raid, where the invitations are run, and talks in it with lumen
 * and nova; nobody films them.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A match lasts as long as it
 * lasts and either may win: a scene ends while its match is on, and the next
 * one waits for it, off camera, and opens on its card.
 *
 * Filmed in the order 3, 0, 4, 5, 6, 7, 1, 2: the cold open is a moment of the
 * match scene 3 starts, each of 5, 6 and 7 opens on the card of the match the
 * one before it left flying, and the home and the practice against the
 * computer come last — the practice from its own tab, the chat behind it
 * already holding the series.
 *
 * Each scene puts, off camera, what it needs in place, so any one of them can
 * be retaken alone: the matches before it are played out first.
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
const GAME = "hex_raid";
const CHANNEL = "#hex-raid";
const HOME = "/games/hex-raid";

/** The series, in the order it is flown. */
const SERIES = ["hex_raid_pacifist", "hex_raid_blitz", "hex_raid"];

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const NOVA = "nova";
// Nobody films them: they make the game's channel a room people are in.
const REGULARS = [BYTEBARD, LUMEN, NOVA];

const EARLIER: Line[] = [
  {
    by: BYTEBARD,
    says: "don't shoot the fuel, you'll need it two screens later",
  },
  { by: NOVA, says: "blitz is brutal, the river is half as wide" },
  { by: LUMEN, says: "drop the mine when they're right behind you" },
];

/** How long a match between two hard jets may take, and some to spare. */
const MATCH_TIMEOUT = 7 * 60_000;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };

test.describe.configure({ mode: "serial" });

test.describe("EP13 Hex Raid", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  // The match flying now, by its place in the series, and its rooms.
  let flying: { index: number; rooms: Rooms } | null = null;
  // How many of the series' matches have their card in the conversation.
  let played = 0;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    // bytebard founds the game's channel, by a match in the ledger.
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      GAME,
      BYTEBARD,
      { p1: 1, p2: 0 },
    );
    kestrel = await person(browser, KESTREL, "America/Chicago");
    await autopilot(kestrel.ctx, "hard");
    pixel = await person(browser, PIXEL, "Europe/Lisbon");
    await autopilot(pixel.ctx, "hard");
    cast.adopt(kestrel);
    for (const nick of [BYTEBARD, LUMEN, NOVA]) {
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
   * Pixel invites kestrel by name from the home, in `wayId`: the chat comes
   * forward on their private conversation with the match's card. Returns the
   * card and the room's address.
   */
  async function invite(
    wayId: string,
    onCamera: boolean,
  ): Promise<{ card: Locator; address: string }> {
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

  /** The same match's card on kestrel's screen. */
  const kestrelCard = (address: string) =>
    kestrel.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();

  /** The series' result cards in the conversation, on Pixel's chat. */
  const resultCards = () =>
    pixel.page
      .locator('[data-testid^="game-result-card-"]')
      .filter({ hasText: KESTREL });

  /** Off camera: match `index` of the series invited, entered and started. */
  async function startOffCamera(index: number): Promise<Rooms> {
    await inTheConversation(kestrel, PIXEL);
    await homeOpen();
    const { address } = await invite(SERIES[index], false);
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    await expect(kestrelCard(address)).toBeVisible({ timeout: 15_000 });
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, SERIES[index]);
    flying = { index, rooms: { host, guest } };
    return flying.rooms;
  }

  /**
   * Off camera: the match flying played out, however long it takes, and its
   * card in the conversation. Should it not come, one like it goes in the
   * ledger instead.
   */
  async function playOut(): Promise<Rooms> {
    const { index, rooms } = flying!;
    for (const room of [rooms.host, rooms.guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: MATCH_TIMEOUT,
      });
    }
    await expect(resultCards())
      .toHaveCount(index + 1, { timeout: 15_000 })
      .catch(async () => {
        await recordMatch(pixel.page.request, SERIES[index], PIXEL, KESTREL, {
          p1: 1500,
          p2: 1200,
        });
        await expect(resultCards()).toHaveCount(index + 1, { timeout: 15_000 });
      });
    played = index + 1;
    return rooms;
  }

  /**
   * Off camera: the match just over, Pixel ends the session it was played in
   * and both close its rooms.
   */
  async function closeRooms() {
    if (!flying) return;
    const { host } = flying.rooms;
    if (!host.isClosed()) {
      await host.getByTestId("p2p-console-end-session").click();
      await host.getByTestId("p2p-confirm-dialog-confirm").click();
      await kestrel.chat.expectMessageVisible("ended the P2P session");
    }
    for (const room of [flying.rooms.host, flying.rooms.guest]) {
      if (!room.isClosed()) await room.close();
    }
    flying = null;
  }

  /**
   * Off camera: match `index` flying, every match before it played out —
   * what the scene before leaves, set up again when a scene is filmed alone.
   */
  async function matchFlying(index: number): Promise<Rooms> {
    if (
      flying?.index === index &&
      !flying.rooms.host.isClosed() &&
      !flying.rooms.guest.isClosed()
    ) {
      return flying.rooms;
    }
    while (played < index) {
      if (flying?.index !== played) await closeRooms();
      if (!flying) await startOffCamera(played);
      await playOut();
      await closeRooms();
    }
    return startOffCamera(index);
  }

  /**
   * Off camera: the match the scene before left flying played out, the next
   * one invited and started; Pixel's chat on their conversation, the latest
   * result card in view.
   */
  async function nextMatchFlying(index: number): Promise<Rooms> {
    await matchFlying(index - 1);
    await playOut();
    await closeRooms();
    const rooms = await startOffCamera(index);
    await pixel.page.bringToFront();
    await resultCards().last().scrollIntoViewIfNeeded();
    await restCursor(pixel.page);
    return rooms;
  }

  test("03 match one", async () => {
    const shot = shotFor(3);
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
        await cue("Pixel picks Pacifist");
        const { card, address } = await invite(SERIES[0], true);
        await restCursor(pixel.page);
        await cue("The invitation lands");
        await focus(card);
        await pointAt(pixel.page, card.getByTestId("share-message-enter"));
        host = await enterRoom(pixel.page, pixel.ctx, address);
        await follow(host);
        await cue("kestrel joins from there");
        layout("full", KESTREL);
        await expect(kestrelCard(address)).toBeVisible({ timeout: 10_000 });
        await focus(kestrelCard(address));
        await cast.say(KESTREL, "best of three?");
        await pointAt(kestrel.page, kestrelCard(address));
        guest = await enterRoom(kestrel.page, kestrel.ctx, address);
        await follow(guest);
        layout("split", PIXEL, KESTREL);
        await cue("Both ready");
        await bothReady(host, guest);
        await restCursor(guest);
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, SERIES[0]);
        await restCursor(host);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    flying = { index: 0, rooms: { host: host!, guest: guest! } };
  });

  test("00 cold open", async () => {
    const shot = shotFor(0);
    const { host, guest } = await matchFlying(0);
    await host.bringToFront();
    // Into the match, past the countdown.
    await host.waitForTimeout(4_000);
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, SERIES[0]));
        await cue("Pixel and kestrel are settling it");
        await focus(matchCanvas(guest, SERIES[0]));
        await cue("It started on the game's home");
        await focus(matchCanvas(host, SERIES[0]));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  /** A match scene that must end with its match still flying. */
  function stillFlying(rooms: Rooms, scene: string) {
    return async () => {
      // The scene is about a match being flown: one already over would put
      // its result under these lines. Retake it.
      if (await rooms.host.getByTestId("lobby-game-result").isVisible()) {
        throw new Error(`the match ended during scene ${scene}: retake it`);
      }
    };
  }

  test("04 no mines", async () => {
    const shot = shotFor(4);
    const rooms = await matchFlying(0);
    const { host, guest } = rooms;
    await host.bringToFront();
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, SERIES[0]));
        await cue("Both jets fly the same river");
        await focus(matchCanvas(guest, SERIES[0]));
        await stillFlying(rooms, "4")();
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  /**
   * Scenes 5 and 6: the card of the match before, on Pixel's chat, then the
   * next match flying on both screens.
   */
  async function cardThenMatch(scene: number, index: number, cues: string[]) {
    const shot = shotFor(scene);
    test.setTimeout(MATCH_TIMEOUT * (index + 1) + 5 * 60_000);
    const rooms = await nextMatchFlying(index);
    const { host, guest } = rooms;
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: pixel.page, [KESTREL]: guest },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(resultCards().last());
        await cue(cues[0]);
        layout("split", PIXEL, KESTREL);
        await host.bringToFront();
        await follow(host);
        await focus(matchCanvas(host, SERIES[index]));
        await cue(cues[1]);
        await focus(matchCanvas(guest, SERIES[index]));
        await stillFlying(rooms, String(scene))();
      },
      { kind: "full", cameras: [PIXEL] },
    );
  }

  test("05 match two", async () => {
    await cardThenMatch(5, 1, [
      "Match two is Blitz",
      "And now the mines come out",
    ]);
  });

  test("06 match three", async () => {
    await cardThenMatch(6, 2, [
      "The last match is Hex Raid itself",
      "everything at once",
    ]);
  });

  test("07 three cards", async () => {
    const shot = shotFor(7);
    test.setTimeout(MATCH_TIMEOUT * 3 + 5 * 60_000);
    // Off camera, the last match plays out — however long it takes.
    const { host, guest } = await matchFlying(2);
    await playOut();
    await expect(resultCards()).toHaveCount(3);
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(host.getByTestId("lobby-game-result"));
        await cue("three cards, all in one conversation");
        layout("full", PIXEL);
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await resultCards().first().scrollIntoViewIfNeeded();
        await restCursor(pixel.page);
        await focus(resultCards().first());
        await cue("Whoever has two");
        await focus(resultCards().last());
        await cast.say(KESTREL, "gg, rematch tomorrow");
        await cue("free to play");
        await focus(resultCards().last());
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await closeRooms();
  });

  test("01 three ways to fly", async () => {
    const shot = shotFor(1);
    await homeOpen();
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(400);
        await focus(page.getByTestId("game-ways"));
        await cue("Hex Raid is the full duel");
        await focus(way(page, "hex_raid"));
        await cue("Pacifist takes the mines away");
        await focus(way(page, "hex_raid_pacifist"));
        await cue("Blitz starts on a narrow river");
        await focus(way(page, "hex_raid_blitz"));
        await cue("you invite a friend by name");
        await inviteForm().scrollIntoViewIfNeeded();
        await focus(inviteForm());
        await pointAt(page, modePicker());
        await cue("First, a practice run");
        await restCursor(page);
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 a practice run", async () => {
    const shot = shotFor(2);
    // Filmed last, the chat behind the home already holds the series: the
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
        await cue("Your fuel runs down");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
