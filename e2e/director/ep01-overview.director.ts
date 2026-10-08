/**
 * Director — EP01, "RetroHexChat: a real IRC client, in your browser".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/01-overview/script.md`;
 * each `film` call below plays one scene's SCREEN directions.
 *
 * The scenes share one viewer — one browser, one nickname — the way the
 * episode reads: whoever connects in scene 1 is who joins #retro in scene 2.
 * Asked for a later scene alone, the viewer signs in off camera first.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/capture FRESH=1
 */
import { BrowserContext, expect, Page, test } from "@playwright/test";
import { pressCtrlShift } from "../helpers/keyboard";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { Cast, Line } from "./cast";
import {
  cameraContext,
  film,
  pointAt,
  restCursor,
  shotFor,
  typeOnCamera,
} from "./shots";

const CONNECT_WINDOW = '[data-testid="landing-connect-window"]';

// The viewer's nickname for the whole episode. A registered nick takes the
// sign-in path instead, so scene 1 needs a fresh database or another nick.
const NICK = process.env.DIRECTOR_NICK || "Pixel";
const PASSWORD = "retro1998";

// Already in #lobby when the viewer arrives. The first founds the channel and
// owns it; the order is casting.
const CAST = ["nova", "kestrel", "lumen", "bytebard", "dialup_dan", "m0dem"];
const TOPIC = "Welcome to #lobby — be excellent to each other";

// The conversation the viewer scrolls into: it happened before they joined.
const EARLIER: Line[] = [
  {
    by: "bytebard",
    says: "anyone else still have a 56k modem in a drawer somewhere?",
  },
  { by: "dialup_dan", says: "mine is on the shelf next to the zip drive 😄" },
  { by: "kestrel", says: "just beat E1M3 in the arcade without saving" },
  { by: "lumen", says: "no way, the secret exit too?" },
  { by: "kestrel", says: "of course. took me an hour to find it in 1994" },
  { by: "m0dem", says: "half the channel is hanging out in the Space tonight" },
  { by: "nova", says: "trivia starts at 9, bring your best 90s facts" },
];

// #retro, founded by kestrel before scene 2, for the viewer to /join.
const RETRO = "#retro";
const RETRO_CAST = ["kestrel", "lumen", "bytebard", "m0dem"];
const RETRO_TOPIC = "Old machines, old games, old friends";
const RETRO_EARLIER: Line[] = [
  { by: "m0dem", says: "found my old Sound Blaster manual today" },
  { by: "lumen", says: "the one with the IRQ jumper chart? classic" },
  { by: "bytebard", says: "IRQ 5, DMA 1. some things you never forget" },
];

test.describe.configure({ mode: "serial" });

test.describe("EP01 overview", () => {
  let cast: Cast;
  let viewerCtx: BrowserContext;
  let viewer: Page;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(3 * 60_000);
    cast = await Cast.assemble(browser, CAST, PASSWORD);
    await cast.command("nova", `/topic ${TOPIC}`);
    await cast.command("nova", "/op kestrel");
    await cast.command("nova", "/voice lumen");
    await cast.command("nova", "/voice bytebard");
    await expect(
      cast.member("nova").page.getByText(TOPIC).first(),
    ).toBeVisible();
    await cast.play(EARLIER);

    viewerCtx = await cameraContext(browser);
    viewer = await viewerCtx.newPage();
  });

  test.afterAll(async () => {
    await viewerCtx?.close();
    await cast?.dismiss();
  });

  /** The viewer's chat, signing in off camera when scene 1 did not run. */
  async function viewerChat(): Promise<ChatPage> {
    const chat = new ChatPage(viewer);
    if (!/\/chat/.test(viewer.url())) {
      const connect = new ConnectPage(viewer);
      await connect.open();
      await connect.signIn(NICK, PASSWORD);
    }
    await chat.waitUntilConnected();
    return chat;
  }

  test("01 connect in five seconds", async () => {
    const shot = shotFor(1);
    const page = viewer;

    // Off camera: the landing has painted and its fonts are in.
    await page.goto("/");
    await expect(page.locator(CONNECT_WINDOW)).toBeVisible();
    await page.evaluate(() => document.fonts.ready);

    await film(page, shot, async ({ pace }) => {
      await pace(1500);
      const nickname = page.locator(`${CONNECT_WINDOW} #nickname`);
      await nickname.click();
      await typeOnCamera(nickname, NICK);
      await pace(500);
      await page
        .locator(`${CONNECT_WINDOW} [data-testid="connect-btn"]`)
        .click();

      const password = page.locator(`${CONNECT_WINDOW} #reg-password`);
      await expect(
        password,
        `"${NICK}" is already registered — film with FRESH=1 or set DIRECTOR_NICK`,
      ).toBeVisible({ timeout: 15_000 });
      await pace(600);
      await typeOnCamera(password, PASSWORD);
      await typeOnCamera(
        page.locator(`${CONNECT_WINDOW} #reg-password-confirm`),
        PASSWORD,
      );
      await pace(400);
      await page
        .locator(`${CONNECT_WINDOW} [data-testid="register-btn"]`)
        .click();

      const chat = new ChatPage(page);
      await chat.waitUntilConnected();
      await restCursor(page);
      await chat.expectMessageVisible(EARLIER.at(-1)!.says);
      await pace(900);
      await cast.say("nova", `hey ${NICK}, welcome to #lobby 👋`);
      await pace(700);
      await cast.say("dialup_dan", "welcome! grab a seat");
      await pace(1500);
    });
  });

  test("02 it's actually IRC", async () => {
    const shot = shotFor(2);
    const chat = await viewerChat();
    const page = viewer;

    // Off camera: #retro exists, has a topic and a conversation.
    for (const nick of RETRO_CAST) await cast.command(nick, `/join ${RETRO}`);
    await cast.command("kestrel", `/topic ${RETRO_TOPIC}`);
    await cast.play(RETRO_EARLIER);
    await restCursor(page);

    await film(page, shot, async ({ pace, cue }) => {
      // The channel as it stands; the pointer follows the tour of it.
      await cue("Channels on the left");
      await pointAt(page, chat.conversationsSidebar);
      await pace(1200);
      await pointAt(page, chat.topicBar);
      await pace(1200);
      await pointAt(page, chat.nicklist);

      await cue("slash commands you remember");
      await chat.chatInput.click();
      await typeOnCamera(chat.chatInput, `/join ${RETRO}`);
      await pace(300);
      await chat.chatInput.press("Enter");
      await chat.expectTabVisible(RETRO);
      await chat.expectMessageVisible(RETRO_EARLIER.at(-1)!.says);
      await pace(600);
      await typeOnCamera(chat.chatInput, "/me waves");
      await chat.chatInput.press("Enter");
      await pace(500);
      await cast.say("lumen", `o/ ${NICK}`);

      // mIRC colours, from the formatting toolbar.
      await cue("mIRC color codes");
      await chat.openFormattingToolbar();
      await pace(400);
      await chat.formatColorButton.click();
      await pace(500);
      await chat.formatColorSwatch(4).click();
      await typeOnCamera(chat.chatInput, "colors work like it's 1999");
      await chat.chatInput.press("Enter");
      await chat.expectMessageVisible("colors work like it's 1999");
      // Closed again: left open, it would sit over the autocomplete.
      await chat.formattingToolbarToggle.click();
      await expect(chat.formattingToolbarPanel).toBeHidden();

      // Every command, one slash away.
      await cue("just type a slash");
      await typeOnCamera(chat.chatInput, "/");
      await expect(chat.autocompleteDropdown).toBeVisible();
      await pace(2200);
      await typeOnCamera(chat.chatInput, "jo");
      await chat.expectAutocompleteContains("/join");
      await pace(1800);
      await chat.chatInput.fill("");
      await expect(chat.autocompleteDropdown).toBeHidden();

      // And the keyboard has a cheatsheet of its own.
      await cue("cheatsheet of their own");
      await pressCtrlShift(page, "/");
      await expect(chat.cheatsheetDialog).toBeVisible();
      await restCursor(page);
    });
  });
});
