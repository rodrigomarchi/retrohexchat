/**
 * Director — EP12, "Hex Warlords: one king each".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/12-hex-warlords/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-warlords.spec.ts: N106, N107).
 *
 * The episode is an invitation by name: Pixel learns the walls against the
 * computer from the game's home, types kestrel's nickname under Play with
 * somebody you know, and the invitation lands in their private conversation
 * as the match; kestrel joins from there, and the result is written into the
 * same conversation. bytebard founds #hex-warlords, where the invitation is
 * run, and talks in it with lumen and nova; nobody films them.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A siege lasts as long as it
 * lasts and either may win: scene 4 ends while it is still on, and scene 5
 * waits for it, off camera, and opens on how it ended.
 *
 * Filmed in the order 3, 0, 4, 5, 1, 2: the cold open is a moment of the
 * match scene 3 starts, and the match's result is Pixel's first in the game
 * (a game's channel tells a player's news once every few minutes), so the
 * home and the practice against the computer come last — the practice from
 * its own tab, the chat behind it already holding the match.
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
const GAME = "hex_warlords";
const CHANNEL = "#hex-warlords";
const HOME = "/games/hex-warlords";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const NOVA = "nova";
// Nobody films them: they make the game's channel a room people are in.
const REGULARS = [BYTEBARD, LUMEN, NOVA];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "catch it at the edge of the shield, it fires steep" },
  { by: NOVA, says: "one king each now, no second chances" },
  { by: LUMEN, says: "the fireball gets fast, watch out" },
];

type Person = TestUser;

test.describe.configure({ mode: "serial" });

test.describe("EP12 Hex Warlords", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  // The match room each player is in, while one is open.
  let rooms: { host: Page; guest: Page } | null = null;

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
    rooms = null;
    await who.page.bringToFront();
    await inTheChannel(who, channel);
    await restCursor(who.page);
  }

  /** Off camera: kestrel's chat on the private conversation with Pixel. */
  async function kestrelInTheConversation() {
    await onlyTheChat(kestrel);
    await kestrel.chat.sendMessage(`/query ${PIXEL}`);
    await expect(kestrel.chat.chatInput).toHaveAttribute(
      "placeholder",
      new RegExp(PIXEL),
    );
    await restCursor(kestrel.page);
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

  /**
   * Pixel invites kestrel by name from the home: the chat comes forward on
   * their private conversation with the match's card. Returns the card and
   * the room's address.
   */
  async function invite(onCamera: boolean): Promise<{
    card: Locator;
    address: string;
  }> {
    const field = inviteForm().getByTestId("game-challenge-nickname");
    if (onCamera) {
      await pointAt(pixel.page, field);
      await field.click();
      await typeOnCamera(field, KESTREL);
      await pointAt(pixel.page, inviteForm().getByTestId("game-challenge"));
    } else {
      await field.fill(KESTREL);
    }
    await inviteForm().getByTestId("game-challenge").click();
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

  /**
   * Off camera: Pixel and kestrel in one match, just started — what scene 3
   * leaves, set up again when a later scene is filmed alone.
   */
  async function matchRunning(): Promise<{ host: Page; guest: Page }> {
    if (rooms && !rooms.host.isClosed() && !rooms.guest.isClosed()) {
      return rooms;
    }
    await kestrelInTheConversation();
    await homeOpen();
    const { address } = await invite(false);
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    await expect(kestrelCard(address)).toBeVisible({ timeout: 15_000 });
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, GAME);
    rooms = { host, guest };
    return rooms;
  }

  test("03 an invitation by name", async () => {
    const shot = shotFor(3);
    await kestrelInTheConversation();
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
        await cue("Pixel types kestrel's nickname");
        const { card, address } = await invite(true);
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
        await cast.say(KESTREL, "you're on");
        await pointAt(kestrel.page, kestrelCard(address));
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

  test("00 cold open", async () => {
    const shot = shotFor(0);
    const { host, guest } = await matchRunning();
    await host.bringToFront();
    // Into the match, past the countdown.
    await host.waitForTimeout(4_000);
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue("The first king to fall");
        await focus(matchCanvas(guest, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("04 the siege", async () => {
    const shot = shotFor(4);
    const { host, guest } = await matchRunning();
    await host.bringToFront();
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue("every brick falls on both screens");
        await focus(matchCanvas(guest, GAME));
        await cue("Nobody gets a second king");
        // The scene is about a match still being played: one already over
        // would put its result under these lines. Retake it.
        if (await host.getByTestId("lobby-game-result").isVisible()) {
          throw new Error("the match ended during scene 4: retake 3, 0 and 4");
        }
        await focus(matchCanvas(host, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("05 one king left", async () => {
    const shot = shotFor(5);
    test.setTimeout(20 * 60_000);
    // Off camera, the siege plays out — however long it takes: two shields
    // at hard bring a king down in two to fifteen minutes.
    const { host, guest } = await matchRunning();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: 17 * 60_000,
      });
    }
    const card = () =>
      pixel.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: KESTREL })
        .last();
    // The result is written into their conversation, on Pixel's chat behind
    // the room. Should it not come, one like it goes in the ledger instead.
    await expect(card())
      .toBeVisible({ timeout: 15_000 })
      .catch(async () => {
        await recordMatch(pixel.page.request, GAME, PIXEL, KESTREL, {
          p1: 1,
          p2: 0,
        });
        await expect(card()).toBeVisible({ timeout: 15_000 });
      });
    await card().scrollIntoViewIfNeeded();
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(host.getByTestId("lobby-game-result"));
        await cue("The result lands right under the invitation");
        layout("full", PIXEL);
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await restCursor(pixel.page);
        await focus(card());
        await cast.say(KESTREL, "rematch tomorrow");
        await cue("free to play");
        await focus(card());
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await host.close();
    await guest.close();
    rooms = null;
  });

  test("01 last king standing", async () => {
    const shot = shotFor(1);
    await homeOpen();
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(400);
        await focus(page.getByTestId("game-home"));
        await cue("one way to play");
        await focus(way(page, GAME));
        await pointAt(page, way(page, GAME).getByTestId("game-play"));
        await cue("this box invites a friend");
        await inviteForm().scrollIntoViewIfNeeded();
        await focus(inviteForm());
        await pointAt(page, inviteForm());
        await cue("First, some practice");
        await restCursor(page);
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 learning the walls", async () => {
    const shot = shotFor(2);
    // Filmed last, the chat behind the home already holds the match: the
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
        await cue("Each castle sits behind its shield");
        const hard = game.getByTestId("retro-game-difficulty-hard");
        await pointAt(game, hard);
        await hard.click();
        await pointAt(game, game.getByTestId("retro-game-start-ai"));
        await game.getByTestId("retro-game-start-ai").click();
        await expect(stageMenu(game)).toBeHidden();
        await restCursor(game);
        await focus(gameCanvas(game, GAME));
        await cue("Hold Space as it lands");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
