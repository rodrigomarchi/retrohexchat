/**
 * Director — EP09, "Star Duel: a rematch, by invitation".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/09-star-duel/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-star-duel.spec.ts: N100, N101).
 *
 * The episode lives in one private conversation, Pixel's with kestrel: the card
 * of their last duel (kestrel won it) leads to the game's home, Pixel warms up
 * against the computer, and sends kestrel a match's link in the same
 * conversation; kestrel takes the seat from its card, and the result lands
 * back in the conversation.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), both at hard. A duel lasts as long as it
 * lasts and either may win: scene 4 ends while it is still on, and scene 5
 * waits for it, off camera, and opens on the result.
 *
 * Filmed in the order 1, 2, 3, 0, 4, 5: scene 1 opens on the last duel's card
 * as the newest in the conversation, so it is filmed before the rematch writes
 * one under it; the cold open is a moment of the duel scene 3 starts.
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
import { Cast } from "./cast";
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
  playFromHome,
  recordMatch,
  stageMenu,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "star_duel";
const HOME = "/games/star-duel";

const PIXEL = "Pixel";
const KESTREL = "kestrel";

// The last duel, kestrel's by two.
const LAST = { p1: 5, p2: 7 };
const INVITE = "you, me, star duel. now.";

type Person = TestUser;

test.describe.configure({ mode: "serial" });

test.describe("EP09 Star Duel", () => {
  let cast: Cast;
  let pixel: Person;
  let kestrel: Person;
  // The match room each player is in, while one is open.
  let rooms: { host: Page; guest: Page } | null = null;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(6 * 60_000);
    kestrel = await person(browser, KESTREL, "America/Chicago");
    await autopilot(kestrel.ctx, "hard");
    pixel = await person(browser, PIXEL, "Europe/Lisbon");
    await autopilot(pixel.ctx, "hard");
    cast = await Cast.assemble(browser, [], PASSWORD);
    for (const member of [pixel, kestrel]) cast.adopt(member);
    // Their last duel, written into their conversation, and what they said
    // after it.
    await recordMatch(pixel.page.request, GAME, PIXEL, KESTREL, LAST);
    await inTheConversation(kestrel, PIXEL);
    await inTheConversation(pixel, KESTREL);
    await expect(lastDuelCard(pixel.page)).toBeVisible({ timeout: 15_000 });
    await cast.say(KESTREL, "gg. you almost had me");
    await pixel.page.waitForTimeout(900);
    await cast.say(PIXEL, "rematch tonight");
  });

  test.afterAll(async () => {
    await cast?.dismiss();
  });

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

  /** Off camera: `who`'s private conversation with `other`, in focus. */
  async function inTheConversation(who: Person, other: string) {
    await who.page.goto("/");
    await who.chat.waitUntilConnected();
    await who.page.waitForTimeout(1500);
    await who.chat.sendMessage(`/query ${other}`);
    await expect(who.chat.chatInput).toHaveAttribute(
      "placeholder",
      new RegExp(other),
    );
  }

  /** The card of the last duel, before the rematch. */
  const lastDuelCard = (page: Page) =>
    page
      .locator('[data-testid^="game-result-card-"]')
      .filter({ hasText: `${LAST.p1} × ${LAST.p2}` })
      .last();

  /**
   * Off camera: every tab but the chat closed, the chat in front on the
   * private conversation, nothing over it.
   */
  async function onlyTheChat(who: Person) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    rooms = null;
    await who.page.bringToFront();
    await inTheConversation(who, who === pixel ? KESTREL : PIXEL);
    await restCursor(who.page);
  }

  /** Off camera: the game on its stage, in Pixel's tab of its own, the menu over it. */
  async function stageOpen(): Promise<Page> {
    await onlyTheChat(pixel);
    await pixel.page.goto(HOME);
    await expect(pixel.page.getByTestId("game-home")).toBeVisible();
    await waitForView(pixel.page);
    const game = await playFromHome(pixel.page, GAME);
    // Behind the stage, the chat is back on the conversation, nothing over it:
    // the invitation is typed there.
    await inTheConversation(pixel, KESTREL);
    await restCursor(pixel.page);
    await game.bringToFront();
    await restCursor(game);
    return game;
  }

  /** Play with someone on the stage: the match room, Pixel's seat taken. */
  async function createMatch(game: Page) {
    await game.getByTestId("play-create-match").click();
    await expect(game).toHaveURL(new RegExp(`/play/${GAME}/`));
    await expect(game.getByTestId("p2p-room-game")).toBeVisible({
      timeout: 20_000,
    });
  }

  /** Share in the room: the match's link, the window closed again. */
  async function shareLink(room: Page): Promise<string> {
    await room.getByTestId("share-create").click();
    const link = await room.getByTestId("share-url").inputValue();
    expect(link).toContain("/join/");
    return link;
  }

  async function closeShare(room: Page) {
    await room.getByTestId("share-close").click();
    await expect(room.getByTestId("share-url")).toBeHidden();
  }

  /** The invitation's card on `who`'s screen, and the Join address it carries. */
  async function invitation(who: Person, link: string) {
    const path = new URL(link).pathname;
    const enter = who.page
      .locator(`[data-testid="share-message-enter"][href$="${path}"]`)
      .last();
    await expect(enter).toBeVisible({ timeout: 15_000 });
    const card = who.page
      .getByTestId("share-message-card")
      .filter({ has: enter })
      .last();
    return {
      card,
      enter,
      address: (await enter.getAttribute("href")) as string,
    };
  }

  /**
   * Off camera: Pixel and kestrel in one duel, just started — what scene 3
   * leaves, set up again when a later scene is filmed alone.
   */
  async function matchRunning(): Promise<{ host: Page; guest: Page }> {
    if (rooms && !rooms.host.isClosed() && !rooms.guest.isClosed()) {
      return rooms;
    }
    const host = await stageOpen();
    await onlyTheChat(kestrel);
    await createMatch(host);
    const link = await shareLink(host);
    await closeShare(host);
    await pixel.chat.sendMessage(`${INVITE} ${link}`);
    const { address } = await invitation(kestrel, link);
    const guest = await enterRoom(kestrel.page, kestrel.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, GAME);
    rooms = { host, guest };
    return rooms;
  }

  test("01 five to seven", async () => {
    const shot = shotFor(1);
    await onlyTheChat(pixel);
    const page = pixel.page;
    const card = lastDuelCard(page);
    await card.scrollIntoViewIfNeeded();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(500);
        await focus(card);
        await cue("The game's name on the card");
        const name = card.getByTestId("game-result-home");
        await pointAt(page, name);
        await pace(300);
        await name.click();
        await expect(page.getByTestId("game-home")).toBeVisible();
        await waitForView(page);
        await restCursor(page);
        await focus(null);
        await cue("The You tab keeps");
        const you = page.getByTestId("game-home-tab-you");
        await pointAt(page, you);
        await you.click();
        const recent = page.getByTestId("game-you-recent");
        await expect(recent).toContainText(KESTREL);
        await restCursor(page);
        await focus(page.getByTestId("game-you-rating"));
        await cue("Including that one");
        await focus(recent.locator("li").first());
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 practice run", async () => {
    const shot = shotFor(2);
    await onlyTheChat(pixel);
    const page = pixel.page;
    await page.goto(HOME);
    await expect(page.getByTestId("game-home")).toBeVisible();
    await waitForView(page);
    await restCursor(page);
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await pace(400);
        const play = way(page, GAME).getByTestId("game-play");
        await pointAt(page, play);
        const game = await openTab(page, play);
        await follow(game);
        await expect(game.getByTestId("retro-game-start-ai")).toBeVisible({
          timeout: 15_000,
        });
        await cue("The menu says it plainly");
        await focus(stageMenu(game).getByTestId("retro-game-goal"));
        await pace(600);
        const normal = game.getByTestId("retro-game-difficulty-normal");
        await pointAt(game, normal);
        await normal.click();
        await pace(300);
        await pointAt(game, game.getByTestId("retro-game-start-ai"));
        await game.getByTestId("retro-game-start-ai").click();
        await expect(stageMenu(game)).toBeHidden();
        await restCursor(game);
        await focus(null);
        await cue("Turn, thrust, and fire");
        await focus(gameCanvas(game, GAME));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 the invitation", async () => {
    const shot = shotFor(3);
    const game = await stageOpen();
    await onlyTheChat(kestrel);
    await game.bringToFront();
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      { [PIXEL]: game, [KESTREL]: kestrel.page },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(400);
        await cue("Play with someone opens a room");
        await pointAt(game, game.getByTestId("play-create-match"));
        await pace(300);
        await createMatch(game);
        host = game;
        await restCursor(game);
        await cue("Share gives it a link");
        await pointAt(game, game.getByTestId("share-create"));
        const link = await shareLink(game);
        await focus(game.getByTestId("share-url"));
        await pace(900);
        await closeShare(game);
        await focus(null);
        await cue("Send the link in a private message");
        await pixel.page.bringToFront();
        await follow(pixel.page);
        await restCursor(pixel.page);
        const input = pixel.chat.chatInput;
        await input.click();
        await typeOnCamera(input, `${INVITE} `);
        await pixel.page.keyboard.insertText(link);
        await pace(300);
        await input.press("Enter");
        const sent = await invitation(pixel, link);
        await focus(sent.card);
        await cue("kestrel sees it");
        layout("full", KESTREL);
        const { enter, address } = await invitation(kestrel, link);
        await pointAt(kestrel.page, enter);
        guest = await enterRoom(kestrel.page, kestrel.ctx, address);
        await follow(guest);
        await follow(host);
        await host.bringToFront();
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
    // Into the duel, past the countdown and the first spawn.
    await host.waitForTimeout(5_000);
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue("Last time, kestrel won");
        await focus(matchCanvas(guest, GAME));
        await cue("Tonight, Pixel asked");
        await focus(matchCanvas(host, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("04 the rematch", async () => {
    const shot = shotFor(4);
    const { host, guest } = await matchRunning();
    await host.bringToFront();
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, GAME));
        await cue("Each hit is a point");
        await focus(matchCanvas(guest, GAME));
        await cue("Nobody here is going to settle");
        // The scene is about a duel still being fought: one already over
        // would put its result under these lines. Retake it.
        if (await host.getByTestId("lobby-game-result").isVisible()) {
          throw new Error("the duel ended during scene 4: retake 3, 0 and 4");
        }
        await focus(matchCanvas(host, GAME));
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
  });

  test("05 seven", async () => {
    const shot = shotFor(5);
    test.setTimeout(10 * 60_000);
    // Off camera, the duel plays out — however long it takes: two ships at
    // hard get to seven in one and a half to three minutes.
    const { host, guest } = await matchRunning();
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: 7 * 60_000,
      });
    }
    // The result is written into their conversation, behind the rooms.
    const card = pixel.page
      .locator('[data-testid^="game-result-card-"]')
      .filter({ hasText: KESTREL })
      .last();
    await expect(card).toBeVisible({ timeout: 15_000 });
    await expect(card).not.toContainText(`${LAST.p1} × ${LAST.p2}`);
    await card.scrollIntoViewIfNeeded();
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [PIXEL]: host, [KESTREL]: guest },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await focus(host.getByTestId("lobby-game-result"));
        await cue("And the result lands");
        layout("full", PIXEL);
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await restCursor(pixel.page);
        await focus(card);
        await cue("free to play");
        await focus(null);
        await pace(0);
      },
      { kind: "split", cameras: [PIXEL, KESTREL] },
    );
    await host.close();
    await guest.close();
    rooms = null;
  });
});
