/**
 * Director — EP11, "Debris Field: the week's challenge".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/11-debris-field/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-debris-field.spec.ts: N104, N105; game-channels.spec.ts:
 * N71).
 *
 * The episode is told through the channel's bot: Scoreboard greets Pixel in
 * #debris-field with this week's challenge, nobody leads it, Pixel practises
 * among the rocks, finds kestrel in the channel, plays the duel to seven, and
 * asks the bot again — and the week has a leader. bytebard founds the channel
 * and talks in it with lumen and nova; nobody films them.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A duel lasts as long as it
 * lasts and either may win: scene 3 ends as it starts, and scene 4 waits for
 * it, off camera, and opens on how it ended.
 *
 * Filmed in the order 1, 3, 0, 4, 5, 2: scene 1 shows a week nobody leads yet,
 * so it goes before any duel; the cold open is a moment of the duel scene 3
 * starts; and the duel's result is Pixel's first in the channel (a game's
 * channel tells a player's news once every few minutes), so the practice
 * against the computer comes last.
 *
 * Each scene puts, off camera, what it needs in place, so any one of them can
 * be retaken alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { Browser, expect, Page, test } from "@playwright/test";
import { TestUser } from "../helpers/chatUsers";
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
  offerSeat,
  openTab,
  provisionGameChannel,
  recordMatch,
  stageMenu,
  startMatch,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "debris_field";
const CHANNEL = "#debris-field";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const LUMEN = "lumen";
const NOVA = "nova";
// Nobody films them: they make the channel a room people are in.
const REGULARS = [BYTEBARD, LUMEN, NOVA];

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "hide behind the big rock, then shoot round it" },
  { by: NOVA, says: "new week, new challenge" },
  { by: LUMEN, says: "nobody's on the board yet" },
];

const TOPIC = "Rocks, missiles, and a new challenge every Monday.";

const CHALLENGE = "This week's challenge is Debris Field.";

type Person = TestUser;

test.describe.configure({ mode: "serial" });

test.describe("EP11 Debris Field", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  // The match room each player is in, while one is open.
  let rooms: { host: Page; guest: Page } | null = null;
  // Whether this run's duel is in the ledger (scene 4 waited for it).
  let dueled = false;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, REGULARS, PASSWORD);
    // bytebard founds the game's channel, by a match in the ledger.
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      GAME,
      BYTEBARD,
      { p1: 3, p2: 7 },
    );
    kestrel = await person(browser, KESTREL, "America/Chicago");
    await autopilot(kestrel.ctx, "hard");
    pixel = await person(browser, PIXEL, "Europe/Lisbon");
    await autopilot(pixel.ctx, "hard");
    cast.adopt(kestrel);
    for (const nick of [BYTEBARD, LUMEN, NOVA, KESTREL]) {
      await inTheChannel(cast.member(nick));
    }
    await cast.command(BYTEBARD, `/topic ${TOPIC}`);
    await expect(kestrel.page.getByText(TOPIC).first()).toBeVisible();
    await cast.play(EARLIER);
  });

  test.afterAll(async () => {
    await cast?.dismiss();
    await pixel?.ctx.close();
  });

  /**
   * Off camera: in the game's channel at its own address, the way
   * game-channels.spec.ts opens it — the address wins over whatever channel
   * the last session ended in, and keeps winning once the restore has run.
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

  /**
   * Off camera: every tab but the chat closed, the chat in front on
   * `channel`, nothing over it.
   */
  async function onlyTheChat(who: Person, channel = CHANNEL) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    rooms = null;
    await who.page.bringToFront();
    await inTheChannel(who, channel);
    await restCursor(who.page);
  }

  /** The game's line under #debris-field's topic, on `page`. */
  const line = (page: Page) => page.getByTestId("game-channel-bar");

  /** Scoreboard's newest line on Pixel's screen that contains `text`. */
  const said = (text: string | RegExp) =>
    pixel.page.locator(".chat-message__text").filter({ hasText: text }).last();

  // The bot answers once per BOT_COOLDOWN_MS in a channel (`Bot.cooldown_ms`)
  // and drops what comes sooner: two questions in a row wait it out.
  const BOT_COOLDOWN_MS = 2_000;
  let lastAnswerAt = 0;

  /** Pixel asks the bot on camera, and its answer comes. */
  async function ask(command: string, answer: string | RegExp) {
    const before = await pixel.page
      .locator(".chat-message__text")
      .filter({ hasText: answer })
      .count();
    const wait = lastAnswerAt + BOT_COOLDOWN_MS + 300 - Date.now();
    if (wait > 0) await pixel.page.waitForTimeout(wait);
    await typeOnCamera(pixel.chat.chatInput, command);
    await pixel.chat.chatInput.press("Enter");
    await expect(
      pixel.page.locator(".chat-message__text").filter({ hasText: answer }),
    ).toHaveCount(before + 1, { timeout: 10_000 });
    lastAnswerAt = Date.now();
    await said(answer).scrollIntoViewIfNeeded();
  }

  /**
   * Off camera: Pixel and kestrel in one duel, just started — what scene 3
   * leaves, set up again when a later scene is filmed alone.
   */
  async function matchRunning(): Promise<{ host: Page; guest: Page }> {
    if (rooms && !rooms.host.isClosed() && !rooms.guest.isClosed()) {
      return rooms;
    }
    await onlyTheChat(pixel);
    await onlyTheChat(kestrel);
    const { address } = await offerSeat(
      pixel.page,
      line(pixel.page).getByTestId("game-channel-lfg"),
      PIXEL,
    );
    const host = await enterRoom(pixel.page, pixel.ctx, address);
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, GAME);
    rooms = { host, guest };
    return rooms;
  }

  test("01 what's the challenge", async () => {
    const shot = shotFor(1);
    await onlyTheChat(pixel);
    const page = pixel.page;
    // The bot told Pixel on arrival what the game is and this week's challenge.
    await expect(said(CHALLENGE)).toBeVisible({ timeout: 15_000 });
    await said(CHALLENGE).scrollIntoViewIfNeeded();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await focus(said("Debris Field: "));
        await cue("this week's challenge");
        await focus(said(CHALLENGE));
        await cue("Type exclamation mark challenge");
        await pixel.chat.chatInput.click();
        await restCursor(page);
        await ask("!challenge", "Nobody leads it yet.");
        await focus(said("Nobody leads it yet."));
        await cue("Right now, nobody leads it");
        await focus(said("Nobody leads it yet."));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 a rival", async () => {
    const shot = shotFor(3);
    await onlyTheChat(pixel);
    await onlyTheChat(kestrel);
    const page = pixel.page;
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: page, [KESTREL]: kestrel.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        await focus(line(page));
        await cue("Find a partner puts a seat");
        const lfg = line(page).getByTestId("game-channel-lfg");
        await pointAt(page, lfg);
        const { card, address } = await offerSeat(page, lfg, PIXEL);
        await restCursor(page);
        await focus(card);
        await cue("Pixel goes in first");
        await pointAt(page, card.getByTestId("share-message-enter"));
        host = await enterRoom(page, pixel.ctx, address);
        await follow(host);
        await cue("kestrel takes the other seat");
        layout("full", KESTREL);
        await cast.say(KESTREL, "you're on");
        const kestrelCard = kestrel.page
          .locator(`[data-testid="share-message-enter"][href="${address}"]`)
          .last();
        await pointAt(kestrel.page, kestrelCard);
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
    // Into the duel, past the countdown.
    await host.waitForTimeout(4_000);
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue("Every game here runs a challenge");
        await focus(matchCanvas(guest, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("04 seven", async () => {
    const shot = shotFor(4);
    test.setTimeout(10 * 60_000);
    // Off camera, the duel plays out — however long it takes: two ships at
    // hard among the rocks reach seven in under a minute, two at worst.
    const { host, guest } = await matchRunning();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: 6 * 60_000,
      });
    }
    const card = () =>
      pixel.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: KESTREL })
        .last();
    // Scoreboard said it in the channel. A duel of Pixel's announced minutes
    // before keeps it out (once every few minutes): then one like it is in
    // the ledger instead.
    await expect(card())
      .toBeVisible({ timeout: 15_000 })
      .catch(async () => {
        await recordMatch(pixel.page.request, GAME, PIXEL, KESTREL, {
          p1: 7,
          p2: 5,
        });
        await expect(card()).toBeVisible({ timeout: 15_000 });
      });
    dueled = true;
    await card().scrollIntoViewIfNeeded();
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(host.getByTestId("lobby-game-result"));
        await cue("the duel is written down");
        layout("full", PIXEL);
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await restCursor(pixel.page);
        await focus(card());
        await cue("The bot posts the result");
        await focus(card());
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await host.close();
    await guest.close();
    rooms = null;
  });

  test("05 top of the week", async () => {
    const shot = shotFor(5);
    // Filmed alone, the week has no duel yet: one like scene 4's goes in the
    // ledger first, so the bot has a leader to name.
    if (!dueled) {
      await recordMatch(pixel.page.request, GAME, PIXEL, KESTREL, {
        p1: 7,
        p2: 5,
      });
      dueled = true;
    }
    await onlyTheChat(pixel);
    const page = pixel.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(300);
        await pixel.chat.chatInput.click();
        await restCursor(page);
        await ask("!challenge", /\(1 win\) leads it\./);
        await focus(said(/\(1 win\) leads it\./));
        await cue("Exclamation mark recent");
        await ask("!recent", / beat /);
        await focus(said(/ beat /));
        await cue("On Monday");
        await focus(null);
        await cue("free to play");
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 among the rocks", async () => {
    const shot = shotFor(2);
    // Filmed last, Pixel's chat already shows the duel and who leads: the
    // camera starts on the game's own tab, opened off camera from the line.
    await onlyTheChat(pixel);
    const game = await openTab(
      pixel.page,
      line(pixel.page).getByTestId("game-channel-play"),
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
        await focus(stageMenu(game));
        await cue("First to seven, on hard");
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
        const hard = game.getByTestId("retro-game-difficulty-hard");
        await pointAt(game, hard);
        await hard.click();
        await focus(null);
        await pointAt(game, game.getByTestId("retro-game-start-ai"));
        await game.getByTestId("retro-game-start-ai").click();
        await expect(stageMenu(game)).toBeHidden();
        await restCursor(game);
        await cue("The rocks block every missile");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
