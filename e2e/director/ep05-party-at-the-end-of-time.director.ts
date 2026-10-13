/**
 * Director — EP05, "A party at the End of Time: Spaces on RetroHexChat".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in
 * `retro_hex_chat_videos/episodes/05-party-at-the-end-of-time/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script.
 *
 * It is kestrel's birthday and #retro throws a party in its Space. Pixel is
 * the viewer and the only camera. Everybody else is a browser of their own
 * with a tab on the Space, walked with the arrow keys (`Walker`): what they
 * say in the script they type in the Space's say line, so the bubble on film
 * is the app's own. wren and sol stay in the chat — which is exactly why they
 * stand on the island anyway, by the lamp.
 *
 * Each scene puts, off camera, the party it needs in place — who is on the
 * island, wearing what, standing where — so any one of them can be retaken
 * alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { Browser, expect, Page, test } from "@playwright/test";
import { followCard } from "../helpers/surfaceEntry";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { Cast, Line } from "./cast";
import {
  cameraContext,
  CrewDirection,
  filmCrew,
  pointAt,
  restCursor,
  shotFor,
  turnTipsOff,
} from "./shots";
import { Walker } from "./space";
import { buildCharacter, enterAs, Look, recipeOf } from "../helpers/characters";

const PASSWORD = "retro1998";
const CHANNEL = "#retro";

const PIXEL = "Pixel";
const LUMEN = "lumen";
const KESTREL = "kestrel";
const BYTEBARD = "bytebard";
const NOVA = "nova";
const HONK = "honk";
// On the island; lumen first, so lumen founds #retro.
const GUESTS = [LUMEN, KESTREL, BYTEBARD, NOVA, HONK];
// In #retro, never opening the map.
const FANS = ["wren", "sol"];

const OUTFIT: Record<string, Look> = {
  [LUMEN]: "mage",
  [KESTREL]: "ranger",
  [BYTEBARD]: "scout",
  [NOVA]: "bard",
  [HONK]: "sailor",
};

// Where the party stands, round the lamp at the middle of the centre island.
type Tile = { x: number; y: number };
const AROUND_THE_LAMP: Record<string, Tile> = {
  [LUMEN]: { x: 47, y: 33 },
  [KESTREL]: { x: 50, y: 33 },
  [BYTEBARD]: { x: 44, y: 37 },
  [NOVA]: { x: 52, y: 38 },
  [HONK]: { x: 54, y: 34 },
  [PIXEL]: { x: 48, y: 39 },
};

// The tour's stops: just short of what there is to see on each island.
const EAST: Record<string, Tile> = {
  [LUMEN]: { x: 75, y: 35 },
  [KESTREL]: { x: 74, y: 38 },
  [BYTEBARD]: { x: 73, y: 34 },
  [NOVA]: { x: 74, y: 36 },
  [HONK]: { x: 72, y: 38 },
  [PIXEL]: { x: 72, y: 36 },
};
const WEST: Record<string, Tile> = {
  [LUMEN]: { x: 24, y: 35 },
  [KESTREL]: { x: 25, y: 37 },
  [BYTEBARD]: { x: 26, y: 34 },
  [NOVA]: { x: 25, y: 36 },
  [HONK]: { x: 27, y: 37 },
  [PIXEL]: { x: 22, y: 37 },
};
const SOUTH: Record<string, Tile> = {
  [LUMEN]: { x: 47, y: 51 },
  [KESTREL]: { x: 50, y: 51 },
  [BYTEBARD]: { x: 46, y: 50 },
  [NOVA]: { x: 49, y: 50 },
  [HONK]: { x: 51, y: 50 },
  [PIXEL]: { x: 48, y: 49 },
};

// The size of a guest's own tab: enough for the say line, cheap to draw.
const GUEST_VIEW = { width: 480, height: 320 };

// The duel, off to one side of the party so the two of them read on screen.
const DUEL: Record<string, Tile> = {
  ...AROUND_THE_LAMP,
  [PIXEL]: { x: 55, y: 43 },
  [HONK]: { x: 58, y: 42 },
};

const EARLIER: Line[] = [
  { by: "wren", says: "evening all 👋" },
  { by: BYTEBARD, says: "who's around tonight" },
  { by: "sol", says: "me, sadly working" },
  { by: KESTREL, says: "just me getting older" },
];

const BIRTHDAY: Line[] = [
  { by: LUMEN, says: "it's kestrel's birthday today 🎂" },
  { by: NOVA, says: "PARTY", then: 400 },
  { by: BYTEBARD, says: "where tho" },
  { by: LUMEN, says: "the island. now.", then: 300 },
];

test.describe.configure({ mode: "serial" });

test.describe("EP05 a party at the End of Time", () => {
  let cast: Cast;
  let pixel: {
    chat: ChatPage;
    page: Page;
    ctx: import("@playwright/test").BrowserContext;
  };
  // Each guest's tab on #retro's Space, and Pixel's.
  const spaces = new Map<string, Walker>();
  let address: string | null = null;
  // Pixel and lumen's private Space, while it is open.
  const privately = new Map<string, Walker>();

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    cast = await Cast.assemble(browser, [...GUESTS, ...FANS], PASSWORD);
    for (const nick of [...GUESTS, ...FANS]) {
      await cast.command(nick, `/join ${CHANNEL}`);
      await cast.member(nick).chat.expectTabVisible(CHANNEL);
      await cast.member(nick).chat.switchToTab(CHANNEL);
    }
    await cast.command(
      LUMEN,
      "/topic the regulars · retro games, old music, late nights",
    );
    pixel = await viewer(browser);
    await pixel.chat.sendMessage(`/join ${CHANNEL}`);
    await pixel.chat.expectTabVisible(CHANNEL);
    await pixel.chat.switchToTab(CHANNEL);
    // The private chat scene 8 opens its Space from.
    await cast.say(LUMEN, `/msg ${PIXEL} psst`);
    await cast.play(EARLIER);
  });

  test.afterAll(async () => {
    await cast?.dismiss();
    await pixel?.ctx.close();
  });

  async function viewer(browser: Browser) {
    const ctx = await cameraContext(browser, PIXEL, {
      timezoneId: "Europe/Lisbon",
    });
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.signIn(PIXEL, PASSWORD);
    await chat.waitUntilConnected();
    await turnTipsOff(page, PIXEL);
    await chat.waitUntilConnected();
    return { chat, page, ctx };
  }

  const guest = (nick: string) => spaces.get(nick)!;

  /** Types a line a word at a time, quickly, the way a person does. */
  async function typeWords(
    field: import("@playwright/test").Locator,
    text: string,
  ) {
    const words = text.split(" ");
    for (const [i, word] of words.entries()) {
      await field.page().keyboard.insertText(i === 0 ? word : ` ${word}`);
      await field.page().waitForTimeout(90);
    }
  }
  const pixelSpace = () => spaces.get(PIXEL);

  /** Off camera: #retro's Space is open, and its card is in the channel. */
  async function spaceAddress(): Promise<string> {
    if (address) return address;
    const lumen = cast.member(LUMEN);
    await lumen.chat.switchToTab(CHANNEL);
    await lumen.page.getByTestId("space-open").click();
    const enter = lumen.page.getByTestId("share-message-enter").last();
    await expect(enter).toBeVisible({ timeout: 15_000 });
    const href = (await enter.getAttribute("href"))!;
    const page = await followCard(lumen.page, lumen.ctx, href);
    await expect(page.getByTestId("space-character-creator")).toBeVisible({
      timeout: 15_000,
    });
    address = page.url();
    await page.close();
    return address;
  }

  /** Someone walks into #retro's Space wearing `avatar`, off camera. */
  async function onTheIsland(
    nick: string,
    avatar: Look,
    page?: Page,
  ): Promise<Walker> {
    const known = spaces.get(nick);
    if (known && !known.page.isClosed()) {
      // A tab that fell back to the door (its LiveView remounted) is no use
      // on the island: open a fresh one.
      if (await known.page.getByTestId("space-say-input").isVisible()) {
        await wear(known, avatar);
        return known;
      }
      console.log(`[director] ${nick}'s Space tab left the island; reopening`);
      await known.page.close();
      spaces.delete(nick);
    }
    const tab =
      page ??
      (await (nick === PIXEL ? pixel.ctx : cast.member(nick).ctx).newPage());
    if (nick !== PIXEL) await offCamera(tab);
    const walker = Walker.follow(tab, { onCamera: nick === PIXEL });
    await tab.goto(await spaceAddress());
    await walkIn(tab, avatar);
    spaces.set(nick, walker);
    return walker;
  }

  /**
   * A guest's own tab, which nobody films: small, and drawing a frame twice a
   * second. Six maps redrawn as fast as the browser allows starve the one
   * camera that matters; a guest walks by key presses, which need no frame.
   */
  async function offCamera(tab: Page) {
    await tab.setViewportSize(GUEST_VIEW);
    await tab.addInitScript(() => {
      window.requestAnimationFrame = (cb) =>
        window.setTimeout(() => cb(performance.now()), 500);
    });
  }

  /** Makes `avatar` at the door and enters; `made` when it is on the preview already. */
  async function walkIn(tab: Page, avatar: Look, made = false) {
    if (made) await tab.getByTestId("space-creator-enter").click();
    else await enterAs(tab, avatar);
    await expect(tab.getByTestId("channel-space-shell")).toBeVisible({
      timeout: 15_000,
    });
    await expect(tab.getByTestId("space-loading")).toBeHidden({
      timeout: 20_000,
    });
  }

  /** Changes into `avatar` from inside, if not wearing it already. */
  async function wear(walker: Walker, avatar: Look) {
    const page = walker.page;
    const shell = page.getByTestId("channel-space-shell");
    if ((await shell.getAttribute("data-avatar")) === recipeOf(avatar)) return;
    await page.getByTestId("space-change-character").click();
    await buildCharacter(page, avatar);
    await page.getByTestId("space-creator-apply").click();
    await expect(page.getByTestId("space-character-creator")).toBeHidden();
  }

  /**
   * Off camera: the whole party is on the island, standing where `spots`
   * says, and Pixel's camera is on Pixel's Space tab in the normal layout.
   */
  async function party(pixelAvatar: Look, spots = AROUND_THE_LAMP) {
    for (const nick of GUESTS) await onTheIsland(nick, OUTFIT[nick]);
    const me = await onTheIsland(PIXEL, pixelAvatar);
    await everyoneTo(spots);
    await leaveFullscreen(me.page);
    await me.page.bringToFront();
    await restCursor(me.page);
    return me;
  }

  /** Everybody walks at once, each their own way. */
  async function everyoneTo(spots: Record<string, Tile>, pace = 160) {
    await Promise.all(
      [...spaces].map(([nick, walker]) =>
        spots[nick] ? walker.goTo(spots[nick], pace) : Promise.resolve(),
      ),
    );
  }

  async function leaveFullscreen(page: Page) {
    const toggle = page.getByTestId("space-fullscreen-toggle");
    if ((await toggle.getAttribute("data-fullscreen")) !== null) {
      await toggle.click();
    }
  }

  /**
   * Where Pixel stands on screen: the map's camera follows its own player, so
   * that is the middle of the canvas. A box `w` by `h` CSS pixels round it,
   * for the edit to zoom on.
   */
  async function aroundMe(page: Page, w = 520, h = 300) {
    const canvas = (await page
      .getByTestId("channel-space-shell")
      .boundingBox())!;
    return {
      x: canvas.x + (canvas.width - w) / 2,
      y: canvas.y + (canvas.height - h) / 2 - 20,
      width: w,
      height: h,
    };
  }

  /** Waits for a line in the script, then its speaker types it in the Space. */
  function sayer(cue: CrewDirection["cue"]) {
    return async (nick: string, words: string, typing = 0) => {
      await cue(words);
      await (privately.get(nick) ?? guest(nick)).say(words, typing);
    };
  }

  /** Everybody goes home: every Space tab closes. */
  async function closeSpaces() {
    for (const walker of [...spaces.values(), ...privately.values()]) {
      if (!walker.page.isClosed()) await walker.page.close();
    }
    spaces.clear();
    privately.clear();
    address = null;
  }

  test("01 the invitation", async () => {
    const shot = shotFor(1);
    await closeSpaces();
    const chatPage = pixel.page;
    await chatPage.bringToFront();
    await pixel.chat.switchToTab(CHANNEL);
    await restCursor(chatPage);
    await filmCrew(
      { [PIXEL]: chatPage },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(800);
        await cue("It's kestrel's birthday");
        await cast.play(BIRTHDAY.slice(0, 2));
        await cue("They could just type");
        await cast.play(BIRTHDAY.slice(2));

        await cue("lumen opens it");
        const lumen = cast.member(LUMEN);
        await lumen.page.getByTestId("space-open").click();
        const card = chatPage
          .locator(
            '[data-testid="share-message-card"][data-share-kind="space"]',
          )
          .last();
        await expect(card).toBeVisible({ timeout: 10_000 });

        await cue("an invitation lands");
        await focus(card);
        // lumen walks in off camera, and the card goes live on its own.
        const href = (await lumen.page
          .getByTestId("share-message-enter")
          .last()
          .getAttribute("href"))!;
        const door = await followCard(lumen.page, lumen.ctx, href);
        address = door.url();
        await door.close();
        await onTheIsland(LUMEN, OUTFIT[LUMEN]);
        await expect(card).toHaveAttribute("data-share-state", "live", {
          timeout: 15_000,
        });

        await cue("Everyone in the channel can follow");
        await pointAt(chatPage, card.getByTestId("share-message-enter"));
        await pace(800);
        await restCursor(chatPage);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 who do you want to be", async () => {
    const shot = shotFor(2);
    const old = pixelSpace();
    if (old && !old.page.isClosed()) await old.page.close();
    spaces.delete(PIXEL);
    for (const nick of GUESTS) await onTheIsland(nick, OUTFIT[nick]);
    await everyoneTo(AROUND_THE_LAMP);
    const chatPage = pixel.page;
    await chatPage.bringToFront();
    await pixel.chat.switchToTab(CHANNEL);
    const card = chatPage
      .locator('[data-testid="share-message-card"][data-share-kind="space"]')
      .last();
    await expect(card).toBeVisible({ timeout: 10_000 });
    await restCursor(chatPage);
    await filmCrew(
      { [PIXEL]: chatPage },
      shot,
      async ({ cue, focus, follow, pace }) => {
        await cue("The party opens in a tab");
        const enter = card.getByTestId("share-message-enter");
        await pointAt(chatPage, enter);
        await pace(300);
        const tab = await followCard(
          chatPage,
          pixel.ctx,
          (await enter.getAttribute("href"))!,
        );
        const me = Walker.follow(tab, { onCamera: true });
        await follow(tab);
        const creator = tab.getByTestId("space-character-creator");
        await expect(creator).toBeVisible({ timeout: 15_000 });
        await restCursor(tab);

        await cue("who do you want to be tonight");
        await focus(creator);
        await cue("eight characters");
        for (const part of ["body", "skin", "outfit", "hair", "hat"]) {
          await pointAt(tab, tab.getByTestId(`space-creator-tab-${part}`));
          await pace(350);
        }
        await pointAt(tab, tab.getByTestId("space-creator-preview"));
        await pace(350);

        await cue("see who's already there");
        await focus(tab.getByTestId("space-roster"));
        await pointAt(tab, tab.getByTestId("space-roster"));

        await cue("Pixel goes with the monk");
        await focus(null);
        await buildCharacter(tab, "monk");
        await pointAt(tab, tab.getByTestId("space-creator-enter"));
        await pace(300);
        // The Walker was listening before the click: the join reply is its
        // first word.
        await walkIn(tab, "monk", true);
        spaces.set(PIXEL, me);
        await restCursor(tab);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 the end of time", async () => {
    const shot = shotFor(3);
    const me = await party("monk");
    const page = me.page;
    // Everyone else paces where they stand, so the island is alive.
    let stopped = false;
    const pacing = [KESTREL, BYTEBARD, NOVA].map(async (nick, i) => {
      const w = guest(nick);
      const home = AROUND_THE_LAMP[nick];
      await w.page.waitForTimeout(i * 500);
      while (!stopped) {
        await w.goTo({ x: home.x + 2, y: home.y }, 260);
        if (stopped) break;
        await w.page.waitForTimeout(900);
        await w.goTo(home, 260);
        await w.page.waitForTimeout(1100);
      }
    });
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(600);
        await cue("Walk with the arrow keys");
        await me.goTo({ x: 48, y: 30 });

        await cue("Bridges lead to the other islands");
        await me.goTo({ x: 48, y: 22 });
        await cue("Up north");
        await me.goTo({ x: 48, y: 16 });

        await cue("No keyboard");
        const pad = page.locator('[data-space-pad-dir="down"]');
        await focus(page.locator(".space-pad-dpad"));
        const box = (await pad.boundingBox())!;
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, {
          steps: 20,
        });
        await page.mouse.down();
        await pace(1600);
        await page.mouse.up();
        await focus(null);
        await restCursor(page);
        await me.goTo({ x: 48, y: 33 }, 150);

        await cue("Those two by the lamp");
        await pace(1500);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    stopped = true;
    await Promise.all(pacing);
  });

  test("04 say it out loud", async () => {
    const shot = shotFor(4);
    const me = await party("monk");
    const page = me.page;
    const line = page.getByTestId("space-say-input");
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async (direction) => {
        const { cue, focus, follow, pace } = direction;
        const say = sayer(cue);
        await cue("Press Enter to talk");
        await focus(line);
        await page.keyboard.press("Enter");
        await expect(line).toBeFocused();
        await typeWords(line, "happy birthday kestrel!!");
        await cue("happy birthday kestrel!!");
        await line.press("Enter");
        await focus(null);
        await say(KESTREL, "you all CAME");
        await say(LUMEN, "obviously");
        await say(BYTEBARD, "who brought the cake");

        await cue("the party and the chat are one conversation");
        await follow(pixel.page);
        await pixel.page.bringToFront();
        await pace(2200);
        await page.bringToFront();
        await follow(page);

        await cue("save me some cake");
        await cast.say("wren", "save me some cake");
        await cue("what are you all doing in there");
        await cast.say("sol", "what are you all doing in there");
        await say(KESTREL, "partying. come in!");
        await say(
          NOVA,
          "kestrel I made you a playlist and it is four hours long and every song is about knights",
        );

        await cue("Press Escape");
        await line.click();
        await line.press("Escape");
        await expect(line).not.toBeFocused();
        await restCursor(page);
        await me.goTo({ x: 50, y: 39 });
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("05 the grand tour", async () => {
    const shot = shotFor(5);
    const me = await party("monk");
    const page = me.page;
    const toggle = page.getByTestId("space-fullscreen-toggle");
    // The walk home finishes after the take: the scene ends on the way back.
    let homeward: Promise<void> = Promise.resolve();
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, pace }) => {
        const say = sayer(cue);
        await say(LUMEN, "tour time. follow me");
        // The first leg starts with lumen's word: every leg is longer than
        // the sentence it belongs to.
        let walking = everyoneTo(EAST);

        await cue("fill the whole screen");
        await pointAt(page, toggle);
        await toggle.click();
        await restCursor(page);

        await cue("Lumen leads the way");
        await say(NOVA, "is that a time machine");
        await say(BYTEBARD, "it's a car. that is also a time machine");
        await walking;
        // Each leg starts a line early: the walk is longer than its sentence.
        walking = everyoneTo(WEST);
        await cue("To the west");
        await say(KESTREL, "relatable");
        await walking;
        walking = everyoneTo(SOUTH);
        await cue("down south");
        await say(PIXEL, "do NOT stand next to that guy");
        await say(BYTEBARD, "his hair is doing the thing");
        await walking;
        await say(KESTREL, "best birthday tour ever");

        await cue("everyone heads back to the lamp");
        homeward = everyoneTo(AROUND_THE_LAMP);
        await pointAt(page, toggle);
        await toggle.click();
        await restCursor(page);
      },
      { kind: "full", cameras: [PIXEL] },
    );
    await homeward;
  });

  test("06 change of outfit", async () => {
    const shot = shotFor(6);
    const me = await party("monk");
    const page = me.page;
    const change = page.getByTestId("space-change-character");
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        const say = sayer(cue);
        await say(NOVA, "Pixel, the monk look is very serious");

        await cue("Changed your mind");
        await pointAt(page, change);
        await pace(300);
        await change.click();
        const creator = page.getByTestId("space-character-creator");
        await expect(creator).toBeVisible();
        await focus(creator);

        await cue("Change it right there");
        await pointAt(page, page.getByTestId("space-creator-preview"));
        await pace(700);
        await buildCharacter(page, "rogue");
        await pointAt(page, page.getByTestId("space-creator-apply"));
        await pace(300);
        await page.getByTestId("space-creator-apply").click();
        await expect(creator).toBeHidden();
        await focus(null);
        await restCursor(page);

        await cue("everyone sees the new look");
        await say(PIXEL, "better?", 70);
        await say(NOVA, "much");
        await say(LUMEN, "very mysterious. very rogue");
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("07 the duel", async () => {
    const shot = shotFor(7);
    const me = await party("rogue", DUEL);
    const page = me.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, focusBox, pace }) => {
        const say = sayer(cue);
        await say(HONK, "one on one. by the lamp. now");
        const honkWalks = guest(HONK).nextTo(PIXEL, 170);
        await say(BYTEBARD, "oh no");
        await say(NOVA, "oh YES");
        await honkWalks;
        focusBox(page, await aroundMe(page));

        await cue("the spacebar swings it");
        await say(PIXEL, "you asked for this", 40);
        await page.locator("canvas").first().focus();

        await cue("takes a bite");
        for (let i = 0; i < 3; i++) {
          await page.keyboard.press(" ");
          await pace(550);
        }
        await cue("Four hits, and you're down");
        await page.keyboard.press(" ");
        await expect(page.getByTestId("space-said")).toHaveText(
          `${HONK} is knocked out!`,
          { timeout: 5_000 },
        );
        await say(KESTREL, "OOF");
        await say(LUMEN, "honk has left the chat. well, the floor");

        await cue("back on your feet");
        await expect(page.getByTestId("space-said")).toHaveText(
          `${HONK} is back on their feet.`,
          { timeout: 10_000 },
        );
        await say(HONK, "best of three");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("08 somewhere quieter", async () => {
    const shot = shotFor(8);
    await party("rogue");
    for (const walker of privately.values()) await walker.page.close();
    privately.clear();
    const chatPage = pixel.page;
    await chatPage.bringToFront();
    await chatPage.getByTestId(`pm-${LUMEN}`).click();
    await restCursor(chatPage);
    await filmCrew(
      { [PIXEL]: chatPage },
      shot,
      async ({ cue, follow, focus, pace }) => {
        await cue("Every private chat has a Space");
        const open = chatPage.getByTestId("space-open");
        await pointAt(chatPage, open);
        await open.click();
        const enter = chatPage.getByTestId("share-message-enter").last();
        await expect(enter).toBeVisible({ timeout: 10_000 });
        const href = (await enter.getAttribute("href"))!;
        const tab = await followCard(chatPage, pixel.ctx, href);
        const me = Walker.follow(tab, { onCamera: true });
        await follow(tab);
        await walkIn(tab, "rogue");
        privately.set(PIXEL, me);
        // lumen follows the same card, off camera.
        const lumenTab = await cast.member(LUMEN).ctx.newPage();
        await offCamera(lumenTab);
        const lumen = Walker.follow(lumenTab);
        await lumenTab.goto(tab.url());
        await walkIn(lumenTab, OUTFIT[LUMEN]);
        privately.set(LUMEN, lumen);
        await restCursor(tab);

        const say = sayer(cue);
        await say(PIXEL, "gift idea for kestrel?", 40);
        await say(LUMEN, "a sword. obviously");

        await cue("your names float over the lamp");
        await lumen.nextTo(PIXEL, 170);

        await cue("stays in your private chat");
        await chatPage.bringToFront();
        await follow(chatPage);
        await focus(chatPage.locator("#chat-messages"));
        await pace(1500);
        await focus(null);
        await tab.bringToFront();
        await follow(tab);

        await say(PIXEL, "a sword AND cake", 40);
        await say(LUMEN, "deal");
        await cue("A quiet corner");
        await pace(500);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("09 the card remembers", async () => {
    const shot = shotFor(9);
    await party("rogue");
    for (const walker of privately.values()) await walker.page.close();
    privately.clear();
    // Pixel has said something in #retro while wearing the rogue.
    await pixel.chat.switchToTab(CHANNEL);
    await pixel.chat.sendMessage("best party on the island 🎉");
    const chatPage = pixel.page;
    await chatPage.bringToFront();
    const card = chatPage
      .locator('[data-testid="share-message-card"][data-share-kind="space"]')
      .last();
    await expect(card).toHaveAttribute("data-share-state", "live", {
      timeout: 15_000,
    });
    await restCursor(chatPage);
    await filmCrew(
      { [PIXEL]: chatPage },
      shot,
      async ({ cue, focus, pace }) => {
        await cue("the card shows the party is still going");
        await card.scrollIntoViewIfNeeded();
        await focus(card);
        await pointAt(chatPage, card);
        await restCursor(chatPage);

        await cue("Your character even follows you");
        const portrait = chatPage
          .locator(`img.rh-portrait[data-avatar="${recipeOf("rogue")}"]`)
          .last();
        await focus(portrait);
        await pace(1200);

        await cue("When the last guest goes home");
        await focus(null);
        for (const walker of spaces.values()) {
          await walker.page.close();
          await pace(250);
        }
        spaces.clear();
        address = null;

        await cue("It becomes the record");
        await expect(card).toHaveAttribute("data-share-state", "ended", {
          timeout: 15_000,
        });
        await card.scrollIntoViewIfNeeded();
        await focus(card);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("10 see you on the island", async () => {
    const shot = shotFor(10);
    const me = await party("rogue");
    await filmCrew(
      { [PIXEL]: me.page },
      shot,
      async ({ cue, pace }) => {
        const say = sayer(cue);
        await say(KESTREL, "same time next year?");
        await cue("Open it, pick a character");
        await guest(LUMEN).say("YES", 0);
        await pace(400);
        await guest(NOVA).say("bring cake", 0);
        await cue("Nothing to install");
        await guest(HONK).say("rematch then", 0);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  // Filmed last: a party filmed first would put its card at the top of the
  // channel that scene 1 shows quiet.
  test("00 cold open", async () => {
    const shot = shotFor(0);
    const me = await party("rogue", DUEL);
    const page = me.page;
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, focusBox, pace }) => {
        await pace(400);
        await guest(KESTREL).say("best birthday ever");
        await pace(500);
        await guest(NOVA).say("🎂🎂🎂");

        await cue("a sword fight by the lamp");
        await guest(HONK).nextTo(PIXEL, 150);
        focusBox(page, await aroundMe(page));
        await page.locator("canvas").first().focus();
        for (let i = 0; i < 4; i++) {
          await page.keyboard.press(" ");
          await pace(420);
        }

        await cue("And all of it started");
        await focus(null);
        await guest(LUMEN).say("told you. the island.");
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });
});
