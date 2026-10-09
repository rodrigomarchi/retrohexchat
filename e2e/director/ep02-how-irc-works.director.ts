/**
 * Director — EP02, "The IRC inside RetroHexChat, command by command against mIRC".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/02-how-irc-works/script.md`;
 * each `film` call below plays one scene's SCREEN directions, and every beat is
 * a flow a spec in `e2e/tests/` already proves — its ID is in the script.
 *
 * One viewer, signed in off camera (the episode never shows the connect
 * screen). Each scene sets up off camera what it needs, so any one of them can
 * be retaken alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/capture FRESH=1
 */
import { BrowserContext, expect, Page, test } from "@playwright/test";
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

const NICK = process.env.DIRECTOR_NICK || "Pixel";
const PASSWORD = "retro1998";

// In #lobby when the viewer arrives. nova joins first and owns #lobby.
const CAST = [
  "nova",
  "kestrel",
  "lumen",
  "bytebard",
  "dialup_dan",
  "m0dem",
  "zephyr",
];
const LOBBY_EARLIER: Line[] = [
  { by: "bytebard", says: "anyone else still type /join out of habit?" },
  { by: "kestrel", says: "every day. my fingers never forgot mIRC" },
  { by: "m0dem", says: "half my aliases are older than some of you" },
  { by: "nova", says: "trivia starts at nine, bring your best 90s facts" },
];

// #retro: kestrel's, moderated, where the viewer is a guest in scene 5.
const RETRO = "#retro";
const RETRO_CAST = ["kestrel", "lumen"];
const RETRO_EARLIER: Line[] = [
  { by: "kestrel", says: "moderated tonight, ask for voice if you want in" },
  { by: "lumen", says: "found my old Sound Blaster manual today" },
];

// #vault: nova's, invite-only, which the viewer knocks on in scene 5.
const VAULT = "#vault";
// nova's private (+p) and lumen's secret (+s) rooms, for the list in scene 3.
const PRIVATE_ROOM = "#backroom";
const SECRET_ROOM = "#hideout";

// The viewer's own channel, founded on camera in scene 3.
const NIGHTSHIFT = "#nightshift";
const NIGHTSHIFT_TOPIC = "Late night radio and old hardware";
const NIGHTSHIFT_CREW = ["lumen", "m0dem", "zephyr"];
const RULES = "house rules: be kind, no spam";

// Scene 2: dialup_dan is away, and says so once.
const AWAY = "brb, someone needs the phone line";

test.describe.configure({ mode: "serial" });

test.describe("EP02 how IRC works", () => {
  let cast: Cast;
  let viewerCtx: BrowserContext;
  let viewer: Page;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(4 * 60_000);
    cast = await Cast.assemble(browser, CAST, PASSWORD);
    await cast.command("nova", "/topic Welcome to #lobby — be excellent");
    await cast.play(LOBBY_EARLIER);

    // #retro: founded by kestrel, moderated before the viewer ever sees it.
    // Every mode below waits for its channel's tab: sent while the join is
    // still landing, it would act on #lobby instead.
    for (const nick of RETRO_CAST) await castIn(nick, RETRO);
    await cast.command("kestrel", "/topic Old machines, old games");
    await cast.command("kestrel", "/voice lumen");
    await cast.play(RETRO_EARLIER);
    await castIn("kestrel", RETRO);
    await setMode("kestrel", "+m");

    // #vault: invite-only, nova inside to hear the knock.
    await castIn("nova", VAULT);
    await setMode("nova", "+i");

    // A private room shows as "Prv"; a secret one does not show at all.
    for (const nick of ["nova", "dialup_dan"]) await castIn(nick, PRIVATE_ROOM);
    await castIn("nova", PRIVATE_ROOM);
    await setMode("nova", "+p");
    await castIn("lumen", SECRET_ROOM);
    await setMode("lumen", "+s");

    await cast.command("dialup_dan", `/away ${AWAY}`);
    for (const nick of CAST) await cast.member(nick).chat.switchToTab("#lobby");

    viewerCtx = await cameraContext(browser, NICK);
    viewer = await viewerCtx.newPage();
  });

  test.afterAll(async () => {
    await viewerCtx?.close();
    await cast?.dismiss();
  });

  /** The viewer's chat, signed in off camera on the first scene that needs it. */
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

  /** Off camera: the viewer is in `channel` and looking at it. */
  async function inChannel(chat: ChatPage, channel: string) {
    if (!(await chat.conversationRow(channel).isVisible())) {
      await chat.sendMessage(`/join ${channel}`);
      await chat.expectTabVisible(channel);
    }
    await chat.switchToTab(channel);
  }

  /** Off camera: a cast member is in `channel` and looking at it. */
  async function castIn(nick: string, channel: string) {
    const { chat } = cast.member(nick);
    if (!(await chat.conversationRow(channel).isVisible())) {
      await chat.sendMessage(`/join ${channel}`);
      await chat.expectTabVisible(channel);
    }
    await chat.switchToTab(channel);
  }

  /** Off camera: a cast member sets a mode on the channel they are looking at. */
  async function setMode(nick: string, mode: string) {
    const { chat } = cast.member(nick);
    await chat.sendMessage(`/mode ${mode}`);
    await chat.expectMessageVisible(`${nick} sets mode ${mode}`);
  }

  /** Types a line on camera and sends it. */
  async function typeAndSend(chat: ChatPage, text: string) {
    await chat.chatInput.click();
    await typeOnCamera(chat.chatInput, text);
    await chat.chatInput.press("Enter");
  }

  /** The app's own mIRC comparison, in a tab of the viewer's browser. */
  async function openParityPage(): Promise<Page> {
    const page = await viewerCtx.newPage();
    await page.goto("/mirc-commands");
    await expect(page.locator("#mirc-commands-heading")).toBeVisible();
    await page.evaluate(() => document.fonts.ready);
    // Every landing page opens its Connect window on top; the table's own
    // introduction is what this episode shows, so it comes to the front.
    await page
      .locator("[data-window-taskbar]", { hasText: "mIRC commands" })
      .click();
    return page;
  }

  test("01 connected, and already identified", async () => {
    const shot = shotFor(1);
    const chat = await viewerChat();
    const page = viewer;
    await chat.switchToTab("#lobby");
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      await pace(800);
      await chat.switchToStatusTab();
      await expect(page.getByText(/Welcome to \S+!/).first()).toBeVisible();
      await focus(chat.statusMessageList);
      await pace(1500);

      await cue("Ask NickServ for info");
      await chat.switchToTab("#lobby");
      await focus(null);
      await typeAndSend(chat, "/ns info");
      await chat.switchToStatusTab();
      await chat.expectStatusMessageVisible(`[NickServ] ${NICK}:`);
      await chat.expectStatusMessageVisible("identified: true");
      await focus(chat.statusMessageList);

      await cue("In mIRC you'd message NickServ");
      await pace(1800);
      await chat.switchToTab("#lobby");
      await focus(null);
      await restCursor(page);
    });
  });

  test("02 talking", async () => {
    const shot = shotFor(2);
    const chat = await viewerChat();
    const page = viewer;
    await chat.switchToTab("#lobby");
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      await cue("Query someone");
      await typeAndSend(chat, "/query lumen");
      await chat.expectTabSelected("lumen");
      await typeAndSend(chat, "hey, got a minute?");
      await cast.command("lumen", `/msg ${NICK} always. what's up?`);
      await chat.expectMessageVisible("always. what's up?");

      // /me works in channels only: in a private chat the handler refuses it.
      await cue("Slash me turns a line");
      await chat.switchToTab("#lobby");
      await typeAndSend(chat, "/me puts the kettle on");
      await chat.expectMessageVisible("puts the kettle on");

      await cue("A notice lands");
      await cast.command("kestrel", `/notice ${NICK} trivia starts at nine`);
      await chat.expectMessageVisible("trivia starts at nine");
      await focus(chat.messageList);

      await cue("when someone is away");
      await focus(null);
      await typeAndSend(chat, "/query dialup_dan");
      await chat.expectTabSelected("dialup_dan");
      await typeAndSend(chat, "you around?");
      await chat.expectMessageVisible(`dialup_dan is away: ${AWAY}`);

      await cue("Ignore is sharper than in mIRC");
      await chat.switchToTab("#lobby");
      await typeAndSend(chat, "/ignore bytebard actions");
      await chat.expectMessageVisible("* bytebard is now ignored (actions)");
      await cast.command("bytebard", "/me does a little dance");
      await cast.say("bytebard", "ok I'll stop dancing now");
      await chat.expectMessageVisible("ok I'll stop dancing now");
      await chat.expectMessageHidden("does a little dance");
      await restCursor(page);
    });

    // Off camera: the viewer reads bytebard in full again.
    await chat.sendMessage("/unignore bytebard");
  });

  test("03 channels", async () => {
    const shot = shotFor(3);
    const chat = await viewerChat();
    const page = viewer;
    await chat.switchToTab("#lobby");
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      await typeAndSend(chat, "/list");
      await expect(chat.channelListSearch).toBeVisible();
      await focus(chat.channelListDialog);

      await cue("A private channel, plus p");
      const placeholder = chat.channelListRow("Prv");
      await expect(placeholder).toBeVisible();
      await expect(chat.channelListRow(SECRET_ROOM)).toBeHidden();
      await pointAt(page, placeholder);
      await pace(1500);

      await cue("Join a channel that doesn't exist");
      await typeOnCamera(chat.channelListSearch, "retro");
      await expect(chat.channelListRow("#lobby")).toBeHidden();
      await expect(chat.channelListRowAction(RETRO)).toHaveText("Join");
      await chat.channelListRow(RETRO).click();
      await chat.expectTabVisible(RETRO);
      await expect(chat.channelListSearch).toBeHidden();
      await focus(null);
      await typeAndSend(chat, `/join ${NIGHTSHIFT}`);
      await chat.expectTabSelected(NIGHTSHIFT);
      await chat.expectNickRole(NICK, "owner");
      await pointAt(page, chat.nicklist);

      await cue("Topic works on the channel you're in");
      await typeAndSend(chat, `/topic ${NIGHTSHIFT_TOPIC}`);
      await expect(chat.topicBar).toContainText(NIGHTSHIFT_TOPIC);
      await focus(chat.topicBar);
      await restCursor(page);
    });
  });

  test("04 who is who", async () => {
    const shot = shotFor(4);
    const chat = await viewerChat();
    const page = viewer;
    await chat.switchToTab("#lobby");
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      await typeAndSend(chat, "/whois kestrel");
      await chat.expectWhoisCard("kestrel");
      await chat.expectLookupCardField("Registered", "Yes");
      // The card scrolls; the row the narration names must be on screen.
      await chat.lookupResultCard
        .locator("dt", { hasText: /^Registered:$/ })
        .scrollIntoViewIfNeeded();
      await focus(chat.lookupResultCard);
      await pace(1500);

      await cue("When someone quits");
      await chat.closeLookupResult();
      await focus(null);
      await cast.leave("bytebard", "/quit off to bed");
      await chat.expectMessageVisible("bytebard has left (off to bed)");
      await typeAndSend(chat, "/whowas bytebard");
      await expect(chat.lookupResultCard).toContainText("Last Seen: bytebard");
      await chat.expectLookupCardField("Quit message", "off to bed");
      await focus(chat.lookupResultCard);

      await cue("a nickname in use stays taken");
      await chat.closeLookupResult();
      await focus(null);
      await typeAndSend(chat, "/nick kestrel");
      await chat.expectMessageVisible("Nickname kestrel is already in use");
      await restCursor(page);
    });

    // Off camera: closed, not just emptied — left open it sits on the taskbar
    // of every scene after this one. The chat window, typed in last, is on top
    // of it, so it comes to the front first.
    await page.locator('[data-window-taskbar="user-lookup"]').click();
    await chat.userLookupDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(chat.userLookupDialog).toBeHidden();
  });

  test("05 a guest in someone else's channel", async () => {
    const shot = shotFor(5);
    const chat = await viewerChat();
    const page = viewer;

    // Off camera: the viewer is a plain guest in #retro and outside #vault,
    // and each channel's operator is looking at it — a command acts on the
    // channel its sender has open.
    await castIn("kestrel", RETRO);
    await castIn("nova", VAULT);
    await inChannel(chat, RETRO);
    await cast.command("kestrel", `/devoice ${NICK}`);
    if (await chat.conversationRow(VAULT).isVisible())
      await chat.sendMessage(`/part ${VAULT}`);
    await chat.switchToTab(RETRO);
    await chat.expectNickRole(NICK, "regular");
    await restCursor(page);

    await film(page, shot, async ({ cue, focus }) => {
      await cue("This channel is moderated");
      await typeAndSend(chat, "can I say something?");
      await chat.expectMessageVisible(
        "Channel is moderated (+m). You need voice (+v) to speak.",
      );

      await cue("An operator gives you voice");
      await cast.command("kestrel", `/voice ${NICK}`);
      await chat.expectNickRole(NICK, "voiced");
      await typeAndSend(chat, "thanks kestrel!");
      await chat.expectMessageVisible("thanks kestrel!");

      await cue("This one is invite-only");
      await chat.viewMenuTrigger.click();
      await chat.channelListMenuItem.click();
      await expect(chat.channelListDialog).toBeVisible();
      await typeOnCamera(chat.channelListSearch, "vault");
      await expect(
        page.getByTestId(`channel-list-invite-only-${VAULT}`),
      ).toBeVisible();
      await expect(chat.channelListRowAction(VAULT)).toHaveText(
        "Request Access...",
      );
      await focus(chat.channelListDialog);
      await chat.channelListRow(VAULT).click();
      await expect(chat.knockRequestDialog).toBeVisible();
      await typeOnCamera(
        chat.knockRequestDialog.getByTestId("knock-request-message"),
        "kestrel sent me",
      );
      await chat.knockRequestDialog.getByTestId("knock-request-submit").click();
      await chat.expectMessageVisible(`Knock sent to ${VAULT}`);
      await focus(null);

      await cue("one invite later");
      await cast.command("nova", `/invite ${NICK}`);
      await chat.acceptInvite(VAULT);
      await chat.expectTabVisible(VAULT);
      await restCursor(page);
    });
  });

  test("06 running your own channel", async () => {
    const shot = shotFor(6);
    const chat = await viewerChat();
    const page = viewer;

    // Off camera: #nightshift is the viewer's, with its crew inside and
    // nobody still banned, opped or muted from an earlier take.
    await inChannel(chat, NIGHTSHIFT);
    await chat.sendMessage(`/unban zephyr`);
    for (const nick of NIGHTSHIFT_CREW) await castIn(nick, NIGHTSHIFT);
    await chat.sendMessage("/deop m0dem");
    await chat.switchToTab(NIGHTSHIFT);
    for (const nick of NIGHTSHIFT_CREW) await chat.expectNickInList(nick);
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      await cue("Start typing mode");
      await chat.chatInput.click();
      await typeOnCamera(chat.chatInput, "/mode ");
      await expect(chat.syntaxTooltip).toContainText("Change channel settings");
      await focus(chat.syntaxTooltip);
      await pace(1200);

      await cue("Plus m, and the channel is moderated");
      await typeOnCamera(chat.chatInput, "+m");
      await chat.chatInput.press("Enter");
      await focus(null);
      await chat.expectMessageVisible(`${NICK} sets mode +m`);
      await pace(600);
      await typeAndSend(chat, "/mode -m");
      await chat.expectMessageVisible(`${NICK} sets mode -m`);

      await cue("Op m0dem");
      await typeAndSend(chat, "/op m0dem");
      await chat.expectNickRole("m0dem", "operator");
      await pointAt(page, chat.nicklist);

      await cue("Someone is spamming");
      await cast.say("zephyr", "HELLO EVERYONE");
      await cast.say("zephyr", "IS THIS THING ON");
      await cast.say("zephyr", "CHECK OUT MY CHANNEL");
      await typeAndSend(chat, "/kick zephyr calm down");
      await chat.expectMessageVisible(
        `zephyr was kicked by ${NICK} (calm down)`,
      );
      await cast.member("zephyr").chat.dismissKickDialog();

      await cue("They're back already");
      await cast.command("zephyr", `/join ${NIGHTSHIFT}`);
      await chat.expectMessageVisible("zephyr has joined the channel");
      await cue("Mute them for five seconds");
      await typeAndSend(chat, "/mute zephyr 5s");
      await chat.expectMessageVisible(
        `zephyr has been muted in ${NIGHTSHIFT}.`,
      );
      const lifted = chat.expectMessageVisible(
        `zephyr has been unmuted in ${NIGHTSHIFT}.`,
        20_000,
      );

      await cue("Still spamming?");
      await lifted;
      await typeAndSend(chat, "/ban zephyr enough");
      await chat.expectMessageVisible(`zephyr was banned by ${NICK} (enough)`);

      await cue("pin a line");
      await cast.say("m0dem", RULES);
      await chat.expectMessageVisible(RULES);
      await chat.openMessageContextMenu(RULES);
      await page.getByTestId("context-menu-item-ctx_chat_pin_message").click();
      await expect(
        page.getByTestId("conversation-toolbar-pinned"),
      ).toContainText("Pinned (1)");
      await chat.openPinnedFromToolbar();
      await expect(chat.pinnedDialog).toContainText(`pinned by ${NICK}`);
      await focus(chat.pinnedDialog);
      await restCursor(page);
    });

    // Off camera: closed, and zephyr's kick and ban notices dismissed.
    await chat.pinnedDialog.locator('[data-window-control="close"]').click();
    await cast
      .member("zephyr")
      .chat.dismissKickDialog()
      .catch(() => {});
  });

  test("07 ChanServ", async () => {
    const shot = shotFor(7);
    const chat = await viewerChat();
    const page = viewer;
    await inChannel(chat, NIGHTSHIFT);
    // Off camera: the topic scene 3 sets, for a take filmed without it.
    await chat.sendMessage(`/topic ${NIGHTSHIFT_TOPIC}`);
    await expect(chat.topicBar).toContainText(NIGHTSHIFT_TOPIC);
    await castIn("lumen", NIGHTSHIFT);
    await chat.switchToTab(NIGHTSHIFT);
    await restCursor(page);

    await film(page, shot, async ({ pace, cue, focus }) => {
      await cue("Register the channel");
      await typeAndSend(chat, "/cs register");
      await chat.expectMessageVisible(
        `[ChanServ] Channel ${NIGHTSHIFT} registered by ${NICK}`,
      );

      await cue("Add lumen to the auto-op list");
      await typeAndSend(chat, "/cs aop add lumen");
      await chat.expectMessageVisible(
        `[ChanServ] lumen added to aop list of ${NIGHTSHIFT}`,
      );

      await cue("every time lumen joins");
      await cast.command("lumen", `/part ${NIGHTSHIFT}`);
      await chat.expectNickNotInList("lumen");
      await cast.command("lumen", `/join ${NIGHTSHIFT}`);
      await chat.expectNickRole("lumen", "operator");
      await pointAt(page, chat.nicklist);

      await cue("Info shows who founded");
      await typeAndSend(chat, "/cs info");
      await chat.expectMessageVisible(
        `[ChanServ] ${NIGHTSHIFT}: founder=${NICK}`,
      );

      await cue("Leave it empty, come back");
      for (const nick of cast.nicks) {
        const member = cast.member(nick);
        if (await member.chat.conversationRow(NIGHTSHIFT).isVisible())
          await member.chat.sendMessage(`/part ${NIGHTSHIFT}`);
      }
      await typeAndSend(chat, `/part ${NIGHTSHIFT}`);
      await chat.expectTabHidden(NIGHTSHIFT);
      await pace(500);
      await typeAndSend(chat, `/join ${NIGHTSHIFT}`);
      await chat.expectTabSelected(NIGHTSHIFT);
      await expect(chat.topicBar).toContainText(NIGHTSHIFT_TOPIC);
      await focus(chat.topicBar);
      await restCursor(page);
    });
  });

  test("08 automation", async () => {
    const shot = shotFor(8);
    const chat = await viewerChat();
    const page = viewer;
    await inChannel(chat, NIGHTSHIFT);
    await castIn("lumen", NIGHTSHIFT);
    await chat.switchToTab(NIGHTSHIFT);
    await chat.expectNickInList("lumen");
    await restCursor(page);

    await film(page, shot, async ({ cue, focus }) => {
      await cue("An alias turns a long command");
      await typeAndSend(chat, "/alias add greet /me waves at $1 in $chan");
      await chat.expectMessageVisible("* Alias /greet created");
      await typeAndSend(chat, "/greet lumen");
      await chat.expectMessageVisible(`waves at lumen in ${NIGHTSHIFT}`);

      await cue("A timer runs a command later");
      await typeAndSend(chat, "/timer kettle 3 /me hears the kettle");
      await chat.expectMessageVisible("* Timer 'kettle' set: one-shot, 3s");
      await chat.expectMessageVisible("hears the kettle", 6_000);

      await cue("Perform runs your commands");
      await typeAndSend(chat, `/perform add /join ${NIGHTSHIFT}`);
      await chat.expectMessageVisible(
        `* Added to perform list: /join ${NIGHTSHIFT}`,
      );

      await cue("popups puts your own commands");
      await chat.openCustomMenusDialogFromCommand();
      await focus(page.getByTestId("custom-menus-window"));
      await chat.addCustomMenuItem(
        "Nicklist",
        "High five",
        "/me high-fives $1",
      );
      await chat.closeCustomMenusDialog();
      await focus(null);
      await chat.nicklistItem("lumen").click({ button: "right" });
      await expect(chat.customContextMenuItem("High five")).toBeVisible();
      await chat.customContextMenuItem("High five").click();
      await chat.expectMessageVisible("high-fives lumen");
      await restCursor(page);
    });
  });

  test("09 not here", async () => {
    const shot = shotFor(9);
    const chat = await viewerChat();
    const page = viewer;
    await chat.switchToTab("#lobby");
    const parity = await openParityPage();
    await page.bringToFront();
    await restCursor(page);

    try {
      await film(page, shot, async ({ pace, cue, follow, focus }) => {
        await follow(parity);
        await parity
          .locator('[data-window-taskbar="parity-elsewhere"]')
          .click();
        const elsewhere = parity.getByTestId("parity-parity-elsewhere");
        await expect(elsewhere).toBeVisible();
        await focus(elsewhere);

        await cue("This is one server");
        await pointAt(parity, elsewhere.getByText("/server host"));

        await cue("Files don't go through DCC");
        await pointAt(parity, elsewhere.getByText("/dcc send nick"));
        await pace(1500);

        await cue("type help and its name");
        await follow(page);
        await typeAndSend(chat, "/help join");
        await expect(chat.inlineHelp).toContainText("Enter a chat channel");
        await focus(chat.inlineHelp);
        await restCursor(page);
      });
    } finally {
      await parity.close();
      await page.bringToFront();
    }
  });

  // Filmed last, like EP01's: the map is shown once the rest is in the can.
  test("00 the map", async () => {
    const shot = shotFor(0);
    const parity = await openParityPage();
    await restCursor(parity);

    try {
      await film(parity, shot, async ({ pace, cue, focus }) => {
        await focus(parity.locator("#mirc-commands-heading"));
        await pace(1500);

        await cue("RetroHexChat keeps a table");
        await parity.locator('[data-window-taskbar="parity-talking"]').click();
        const talking = parity.getByTestId("parity-parity-talking");
        await expect(talking).toBeVisible();
        await focus(talking);
        await pointAt(parity, talking);

        await cue("Most of them are the same");
        await parity.locator('[data-window-taskbar="parity-channels"]').click();
        const channels = parity.getByTestId("parity-parity-channels");
        await expect(channels).toContainText("/join #channel key");
        await focus(channels);
        await pointAt(parity, channels);

        await cue("let's open the chat");
        await restCursor(parity);
      });
    } finally {
      await parity.close();
    }
  });
});
