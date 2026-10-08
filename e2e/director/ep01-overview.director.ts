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
import { TestUser } from "../helpers/chatUsers";
import { adminNick, adminPassword, e2eURL } from "../helpers/env";
import { pressCtrlShift } from "../helpers/keyboard";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import {
  closeDoom,
  openArcade,
  playDoom,
  previewDoom,
  readyDoom,
  resetArcade,
  startDoom,
  warmDoom,
} from "./arcade";
import {
  endSession,
  joinConference,
  openConferenceAt,
  openSession,
  propFile,
  sendFile,
  Session,
  startHexPong,
} from "./calls";
import { Cast, Line } from "./cast";
import { openSpace, pickAvatar, walk, wander } from "./space";
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

// The viewer's own channel in scene 3: brand new, so whoever joins first owns it.
const HAVEN = "#pixelhaven";

// #lobby's bot, made by the server operator off camera. A server operator is
// the only one who can make a bot, and is never filmed.
const BOT = "Patches";
const BOT_SETUP = [
  `/bot create ${BOT} Lobby attendant`,
  `/bot set ${BOT} cooldown 1000`,
  `/bot set ${BOT} greeting_delivery public`,
  `/bot set ${BOT} greeting Welcome to #lobby, {nickname}! I'm ${BOT}, the lobby attendant.`,
  `/bot set ${BOT} dice_default 1d20`,
  `/bot set ${BOT} trivia_category general`,
  `/bot set ${BOT} trivia_time 30`,
  `/bot set ${BOT} trivia_questions 3`,
  `/bot join ${BOT} #lobby`,
];

// Who is already walking around #retro's Space when the viewer opens it.
const SPACE_CROWD: [string, string][] = [
  ["kestrel", "knight"],
  ["lumen", "sorceress"],
  ["bytebard", "archer"],
  ["m0dem", "rogue"],
];

// Scene 8: links the cast shares, and a friend the viewer watches for.
const LINKS = [e2eURL("/mirc-commands"), e2eURL("/games")];
const FRIEND = "orbit";

// Scene 5: who the viewer calls, and who is already in #retro's conference.
const CALLEE = "lumen";
const CONFERENCE = ["kestrel", "bytebard", "m0dem"];

// Scene 7: the viewer's two-player opponent.
const OPPONENT = "kestrel";

// Scene 0: #lobby talking while the camera watches.
const LIVELY: Line[] = [
  { by: "kestrel", says: "anyone up for a deathmatch later?", then: 1500 },
  {
    by: "lumen",
    says: "only if I get the rocket launcher this time",
    then: 1500,
  },
  {
    by: "dialup_dan",
    says: "brb, someone needs the phone line 😄",
    then: 1500,
  },
  { by: "nova", says: "some things never change", then: 1500 },
];

// Walks into #lobby during scene 4, for Patches to greet.
const NEWCOMER = "zephyr";

/**
 * The server operator makes the bot and leaves. It runs after the cast has
 * founded #lobby (an operator joining first would own it) and before the
 * viewer arrives, so the operator never appears on screen.
 */
async function setUpBot(cast: Cast) {
  const operator = await cast.enterAs(adminNick(), adminPassword());
  for (const command of BOT_SETUP) await operator.chat.sendMessage(command);
  await expect(cast.member("nova").chat.nicklist).toContainText(BOT, {
    timeout: 15_000,
  });
  await cast.leave(adminNick(), "/quit");
}

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
    await setUpBot(cast);
    await cast.play(EARLIER);

    // #retro exists, has a topic and a conversation, for scene 2 to /join.
    for (const nick of RETRO_CAST) await cast.command(nick, `/join ${RETRO}`);
    await cast.command("kestrel", `/topic ${RETRO_TOPIC}`);
    await cast.play(RETRO_EARLIER);

    viewerCtx = await cameraContext(browser, NICK);
    viewer = await viewerCtx.newPage();
  });

  test.afterAll(async () => {
    await viewerCtx?.close();
    await cast?.dismiss();
  });

  /** The viewer as the suite's helpers expect a user. */
  function viewerUser(chat: ChatPage): TestUser {
    return {
      chat,
      connect: new ConnectPage(viewer),
      ctx: viewerCtx,
      page: viewer,
      nick: NICK,
      password: PASSWORD,
    };
  }

  /** Off camera: the viewer is in `channel`, for a scene filmed without the one that joined it. */
  async function inChannel(chat: ChatPage, channel: string) {
    if (!(await chat.conversationRow(channel).isVisible())) {
      await chat.sendMessage(`/join ${channel}`);
      await chat.expectTabVisible(channel);
    }
    await chat.switchToTab(channel);
  }

  /** The viewer's chat, signing in off camera when scene 1 did not run. */
  async function viewerChat(): Promise<ChatPage> {
    const chat = new ChatPage(viewer);
    if (new URL(viewer.url()).pathname !== "/chat") {
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

    await film(page, shot, async ({ pace, focus }) => {
      await pace(1500);
      const nickname = page.locator(`${CONNECT_WINDOW} #nickname`);
      await nickname.click();
      await focus(page.locator(CONNECT_WINDOW));
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
      await focus(null);
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

    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
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
      await focus(chat.autocompleteDropdown);
      await pace(2200);
      await typeOnCamera(chat.chatInput, "jo");
      await chat.expectAutocompleteContains("/join");
      await pace(1800);
      await chat.chatInput.fill("");
      await expect(chat.autocompleteDropdown).toBeHidden();
      await focus(null);

      // And the keyboard has a cheatsheet of its own.
      await cue("cheatsheet of their own");
      await pressCtrlShift(page, "/");
      await expect(chat.cheatsheetDialog).toBeVisible();
      await focus(chat.cheatsheetDialog);
      await restCursor(page);
    });

    // Off camera: closed, not just hidden — Escape leaves it on the taskbar.
    await chat.cheatsheetCloseButton.click();
    await expect(chat.cheatsheetDialog).toBeHidden();
  });

  test("03 channels you can actually run", async () => {
    const shot = shotFor(3);
    const chat = await viewerChat();
    const page = viewer;
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      // A channel nobody has opened yet: whoever joins first owns it.
      await chat.chatInput.click();
      await typeOnCamera(chat.chatInput, `/join ${HAVEN}`);
      await chat.chatInput.press("Enter");
      await chat.expectTabVisible(HAVEN);

      await cue("Channel Central puts it all");
      await chat.openChannelCentralFromMenu();
      await focus(chat.channelCentralDialog);
      await pace(900);
      await chat.switchChannelCentralToTab("modes");
      const modes = chat.channelCentralPanel("modes");
      await pace(700);
      await modes.getByLabel("Moderated (+m)").check();
      await pace(400);
      await modes.getByLabel("Topic Lock (+t)").check();
      await pace(400);
      await modes.getByRole("button", { name: "Apply Modes" }).click();
      await expect(modes.getByLabel("Moderated (+m)")).toBeChecked();

      await cue("register your channel with ChanServ");
      await chat.switchChannelCentralToTab("registration");
      const status = chat.channelCentralDialog.getByTestId("cc-cs-status");
      await expect(status).toContainText("Not registered");
      await pace(900);
      await page.getByTestId("cc-cs-register").click();
      await expect(status).toContainText("Registered");

      await cue("Bans are persistent");
      await chat.switchChannelCentralToTab("access_lists");

      await cue("This is the kind of depth");
      await chat.closeChannelCentral();
      await focus(null);
      await restCursor(page);
    });
  });

  test("04 bots that do real work", async () => {
    const shot = shotFor(4);
    const chat = await viewerChat();
    const page = viewer;
    await chat.switchToTab("#lobby");
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      // The newcomer is on the way in while the bot is introduced.
      const arriving = cast.enter(NEWCOMER);
      await pace(600);
      await pointAt(page, chat.nicklist);

      await cue("greets everyone who walks in");
      await focus(chat.messageList);
      await arriving;
      await chat.expectMessageVisible(`Welcome to #lobby, ${NEWCOMER}!`);
      await restCursor(page);

      await cue("roll dice");
      await chat.chatInput.click();
      await typeOnCamera(chat.chatInput, `!${BOT} roll 2d6`);
      await chat.chatInput.press("Enter");
      await chat.expectMessageVisible("Rolling 2d6");

      await cue("Start a round of trivia");
      await typeOnCamera(chat.chatInput, `!${BOT} trivia start`);
      await chat.chatInput.press("Enter");
      await chat.expectMessageVisible("Q1/");
      await restCursor(page);
    });

    // Off camera: a running quiz would keep posting into #lobby.
    await chat.sendMessage(`!${BOT} trivia stop`);
  });

  test("05 calls, files and conferences", async () => {
    const shot = shotFor(5);
    const chat = await viewerChat();
    const page = viewer;
    const me = viewerUser(chat);
    const file = propFile("retro-games-pack.zip", 200);
    await inChannel(chat, RETRO);

    // Off camera: part of the cast is already in #retro's conference.
    const conference: Page[] = [];
    for (const nick of CONFERENCE) {
      const member = cast.member(nick);
      await member.chat.switchToTab(RETRO);
      const call = await openConferenceAt(member);
      await joinConference(call);
      conference.push(call);
    }
    // The call is offered in the private chat: its card must be the newest
    // one there, and #retro now holds the conference's.
    await chat.sendMessage(`/query ${CALLEE}`);
    await chat.expectTabVisible(CALLEE);
    await restCursor(page);

    let session: Session | undefined;
    let mine: Page | undefined;
    try {
      await film(page, shot, async ({ pace, cue, follow, focus }) => {
        await chat.chatInput.click();
        await typeOnCamera(chat.chatInput, `/p2p ${CALLEE}`);
        // openSession sends it; the camera follows the viewer's session tab.
        session = await openSession(me, cast.member(CALLEE), follow);

        await cue("Send a file the same way");
        await sendFile(session, file);
        await focus(session.inviter.getByTestId("lobby-file-panel"));

        await cue("whole channel wants to talk");
        await follow(page);
        await chat.switchToTab(RETRO);
        mine = await openConferenceAt(me);
        await follow(mine);

        await cue("A device check before you join");
        await pace(1200);
        await joinConference(mine);
        await pace(1500);
        await mine.getByTestId("group-call-hand-toggle").click();
        await restCursor(mine);
      });
    } finally {
      // Off camera: everyone hangs up.
      if (session) await endSession(session);
      await mine?.close();
      for (const call of conference) await call.close();
      await page.bringToFront();
    }
  });

  test("06 spaces: walk into the conversation", async () => {
    const shot = shotFor(6);
    const chat = await viewerChat();
    const page = viewer;

    // Off camera: the crowd is already in #retro's Space, pacing about.
    const crowd: Page[] = [];
    for (const [nick, avatar] of SPACE_CROWD) {
      const member = cast.member(nick);
      await member.chat.switchToTab(RETRO);
      const space = await openSpace(member.page, member.ctx);
      await pickAvatar(space, avatar);
      crowd.push(space);
    }
    let done = false;
    const pacing = crowd.map((space, i) => wander(space, i * 450, () => done));
    await inChannel(chat, RETRO);
    await restCursor(page);

    let space: Page | undefined;
    try {
      await film(page, shot, async ({ pace, cue, follow, focus }) => {
        await cue("has a Space");
        space = await openSpace(page, viewerCtx);
        await follow(space);

        await cue("pick a character");
        await pace(500);
        await pickAvatar(space, "monk");

        await cue("Messages appear above");
        await cast.say("lumen", `hey ${NICK}, over here!`);

        await cue("wander off");
        await walk(space, "ArrowRight", 3);
        await pace(300);
        await walk(space, "ArrowUp", 2);

        await cue("start a fight");
        await pace(600);
        await space.keyboard.press("Space");
        await pace(700);
        await space.keyboard.press("Space");
        await restCursor(space);
      });
    } finally {
      done = true;
      await Promise.all(pacing);
    }

    // Off camera: everyone leaves the Space; the viewer is back in the chat.
    await space?.close();
    for (const tab of crowd) await tab.close();
    await page.bringToFront();
  });

  test("07 the arcade", async () => {
    const shot = shotFor(7);
    const chat = await viewerChat();
    const page = viewer;
    const me = viewerUser(chat);

    // Off camera: DOOM loaded once, so its 7.5 MB are cached and Play is
    // quick on camera; and a Hex Pong match with kestrel already running.
    await warmDoom(viewerCtx);
    await resetArcade(page, chat);
    await chat.sendMessage(`/query ${OPPONENT}`);
    await chat.expectTabVisible(OPPONENT);
    const match = await openSession(me, cast.member(OPPONENT));
    await startHexPong(match);
    await page.bringToFront();
    await restCursor(page);

    let doom: Page | undefined;
    try {
      await film(page, shot, async ({ pace, cue, follow, focus }) => {
        await openArcade(page, chat);
        await focus(page.getByTestId("arcade-games-window"));
        await restCursor(page);

        await cue("you'll find DOOM");
        await pace(1500);
        await previewDoom(page);
        await pace(1200);
        // Play now: the game loads while the list is still being read out.
        doom = await startDoom(page, viewerCtx);
        await restCursor(page);
        await readyDoom(doom);

        await cue("They run in your browser");
        await follow(doom);
        await playDoom(doom, 2800);

        await cue("invite them to a two-player game");
        await follow(match.inviter);
        await restCursor(match.inviter);

        await cue("syncs directly");
        await match.invitee.keyboard.down("ArrowUp");
        await match.inviter.keyboard.down("ArrowDown");
        await pace(1200);
        await match.invitee.keyboard.up("ArrowUp");
        await match.inviter.keyboard.up("ArrowDown");
      });
    } finally {
      if (doom) await closeDoom(page, doom);
      await resetArcade(page, chat);
      await endSession(match);
      await page.bringToFront();
    }
  });

  test("08 small things that add up", async () => {
    const shot = shotFor(8);
    const chat = await viewerChat();
    const page = viewer;

    // Off camera: links have gone by in #retro, and a friend is on the
    // viewer's notify list, registered but offline — so on camera they only
    // sign in, which is quick enough to land inside one sentence.
    await cast.enter(FRIEND);
    await cast.leave(FRIEND);
    await chat.switchToStatusTab();
    await chat.sendMessage(`/notify add ${FRIEND}`);
    await inChannel(chat, RETRO);
    await cast.say("bytebard", `the full command list: ${LINKS[0]}`);
    await cast.say("m0dem", `and every game we have: ${LINKS[1]}`);
    const card = chat.messageRowByText(LINKS[1]).locator(".chat-link-card");
    let arriving: Promise<unknown> = Promise.resolve();
    await expect(card).toBeVisible({ timeout: 30_000 });
    await restCursor(page);

    // The notify list reports an arrival ~10 s after it happens (it debounces),
    // so the friend starts signing in before the camera does, to turn Online
    // while the list is on screen.
    arriving = cast.enter(FRIEND);
    await page.waitForTimeout(4000);

    await film(page, shot, async ({ pace, cue, focus }) => {
      await cue("A URL catcher");
      await chat.openUrlCatcherFromMenu();
      await focus(chat.urlCatcherDialog);
      await expect(chat.urlCatcherRowByUrl(LINKS[0])).toBeVisible();
      await restCursor(page);

      await cue("Link previews");
      await chat.urlCatcherDialog
        .locator('[data-window-control="close"]')
        .click();
      await pointAt(page, card);
      await focus(card);

      await cue("buddy list");
      await chat.openNotifyListFromMenu();
      await focus(chat.notifyListDialog);
      await restCursor(page);

      await cue("Full-text search");
      await chat.closeNotifyList();
      await pressCtrlShift(page, "F");
      await expect(chat.searchBar).toBeVisible();
      await focus(chat.messageList);
      await typeOnCamera(chat.searchBarInput, "IRQ");
      await expect(page.locator("mark.search-highlight").first()).toBeVisible();

      await cue("help system");
      await page.keyboard.press("Escape");
      await chat.openHelpTopicsFromMenu();
      await focus(null);
      await pace(1200);
      await page.getByRole("tab", { name: "Index" }).click();
      await pace(1200);
      await page.getByRole("tab", { name: "Search" }).click();
      await restCursor(page);
    });

    // The friend's sign-in must have finished: a failed one fails the take.
    await arriving;

    // Off camera: back from the help desktop to the chat.
    await page.goBack();
    await chat.waitUntilConnected();
  });

  test("09 open source", async () => {
    const shot = shotFor(9);
    const chat = await viewerChat();
    const page = viewer;
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      // Start ▸ Help holds the licence, the source and About together.
      await chat.openStartGroup(chat.helpSubmenuTrigger, chat.startAboutItem);
      await focus(page.locator("[data-window-start-menu]"));
      await pointAt(page, page.getByTestId("start-menu-item-license"));
      await pace(1500);
      await pointAt(page, page.getByTestId("start-menu-item-github"));

      await cue("Under the hood");
      await chat.startAboutItem.click();
      await expect(chat.aboutDialog).toBeVisible();
      await focus(chat.aboutDialog);
      await restCursor(page);

      await cue("use it right now");
      await page.keyboard.press("Escape");
      await expect(chat.aboutDialog).toBeHidden();
      await focus(null);
    });
  });

  // Filmed last: the cold open shows the room at its liveliest, and reuses the
  // DOOM cache scene 7 warmed.
  test("00 cold open", async () => {
    const shot = shotFor(0);
    const chat = await viewerChat();
    const page = viewer;
    await resetArcade(page, chat);
    await chat.switchToTab("#lobby");
    await restCursor(page);

    let doom: Page | undefined;
    try {
      await film(page, shot, async ({ pace, cue, follow, focus }) => {
        // #lobby keeps talking while the camera watches.
        const talking = cast.play(LIVELY);

        // The Arcade opens early: DOOM needs a few seconds to be playable.
        await cue("It runs in your browser");
        await openArcade(page, chat);
        await focus(page.getByTestId("arcade-games-window"));
        await pace(800);
        await previewDoom(page);
        await pace(800);
        doom = await startDoom(page, viewerCtx);
        await restCursor(page);
        await readyDoom(doom);
        await talking;

        await cue("that's DOOM");
        await follow(doom);
        await playDoom(doom, 4000);
      });
    } finally {
      if (doom) await closeDoom(page, doom);
    }
  });
});
