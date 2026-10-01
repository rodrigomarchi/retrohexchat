/**
 * @section Dialog Gallery
 * @flow DG1 [done] Every reworked dialog body opens and is photographed into e2e/screenshots/dialog-gallery for visual audit
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 *
 * One dialog is deliberately absent: the Share link dialog belongs to a
 * surface rather than to the chat desktop, so no chat window opens it. It has a
 * banner; it is not photographed here.
 *
 * The admin-only windows are photographed by the second describe block, which
 * signs in as the administrator `config/e2e.exs` names. It is a separate
 * session rather than a flag on the first one because every one of its shots
 * needs server-wide powers, and a gallery of ordinary windows taken by an
 * administrator would not be the gallery an ordinary person sees.
 *
 * This spec is the visual half of the dialog grammar work. It asserts the
 * banner is there — a dialog that lost its illustration fails here — and
 * writes a PNG per dialog so the drawing itself can be judged by eye. The
 * screenshots are build output, not fixtures: nothing compares them.
 */
import {
  test,
  expect,
  type Browser,
  type Locator,
  type Page,
} from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import {
  ADMIN_NICK,
  ADMIN_PW,
  knownSignedInUser,
  newSignedInUser,
  uniqueChannel,
  type TestUser,
} from "../helpers/chatUsers";

const SHOTS = "screenshots/dialog-gallery";

// The smallest thing the emoji upload will accept. The gallery photographs the
// window with something in it, so it has to put something in it.
const ONE_PIXEL_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

async function shoot(page: Page, target: Locator, name: string) {
  await expect(target).toBeVisible();
  await page.waitForTimeout(350);
  await target.screenshot({ path: `${SHOTS}/${name}.png` });
}

/**
 * A banner is the contract: the dialog says what it is before it asks
 * anything. `scope` narrows where the banner is looked for — a tabbed dialog
 * keeps every panel in the DOM, so the first banner found belongs to whichever
 * tab was built first, not to the one on screen.
 */
async function shootWithBanner(
  page: Page,
  target: Locator,
  name: string,
  scope: Locator = target,
) {
  const banner = scope.locator("[data-dialog-banner]").first();
  await expect(banner).toBeVisible();
  await shoot(page, target, name);

  // The miniature on its own, so "is this the same picture as that one" is a
  // question a checksum answers. Two banners that render identically are one
  // picture repeated, whatever the call sites intended.
  const art = banner.locator(".dlg-banner__art").first();
  if (await art.isVisible().catch(() => false)) {
    await art.screenshot({ path: `${SHOTS}/art/${name}.png` });
  }
}

/**
 * Asserts a control sits wholly within the window that owns it.
 *
 * A window-scoped dialog is clipped by its host window, not by the viewport,
 * so a control pushed past the bottom edge is still "visible" to Playwright
 * and still unreachable to a person.
 */
async function expectInsideWindow(control: Locator, window: Locator) {
  const [inner, outer] = await Promise.all([
    control.boundingBox(),
    window.boundingBox(),
  ]);

  expect(inner, "the control has no box").not.toBeNull();
  expect(outer, "the window has no box").not.toBeNull();
  expect(inner!.y + inner!.height).toBeLessThanOrEqual(
    outer!.y + outer!.height,
  );
}

test.describe("dialog gallery", () => {
  test.describe.configure({ mode: "serial" });

  let user: TestUser;
  let channel: string;
  let browserRef: Browser;

  test.beforeAll(async ({ browser }) => {
    browserRef = browser;
    user = await newSignedInUser(browser, "gal", "pass12345");
    channel = uniqueChannel("gallery");
    await user.chat.sendMessage(`/join ${channel}`);
    await user.page.waitForTimeout(1000);
    await user.chat.sendMessage("/topic Everything about the new dialogs");
    await user.page.waitForTimeout(400);
    await user.chat.sendMessage("/setwelcome Read the topic, then say hello.");
    await user.page.waitForTimeout(600);
    await user.chat.sendMessage("/cs register");
    await user.page.waitForTimeout(800);
    await user.chat.sendMessage("/ban Patches being loud");
    await user.page.waitForTimeout(600);
    await user.chat.sendMessage("the rules live at https://example.com/rules");
    await user.page.waitForTimeout(600);

    // A pin needs a line to pin, and the Pinned toolbar button only exists
    // once the channel keeps something.
    await user.chat.openMessageContextMenu("the rules live at");
    await user.page
      .getByTestId("context-menu-item-ctx_chat_pin_message")
      .click();
    await user.page.waitForTimeout(800);
  });

  test.afterAll(async () => {
    await user?.ctx.close();
  });

  test("account", async () => {
    await user.chat.openAccountRegisterFromMenu();
    await shootWithBanner(user.page, user.chat.accountDialog, "account");
    await user.page.keyboard.press("Escape");
  });

  test("profile", async () => {
    await user.chat.openAccountProfileFromMenu();
    await user.chat.profileDialog
      .getByTestId("profile-bio")
      .fill("Runs the arcade nights. Ask me about Warlords.");
    await user.page.waitForTimeout(400);
    await shootWithBanner(user.page, user.chat.profileDialog, "profile");
    await user.page.keyboard.press("Escape");
  });

  test("away", async () => {
    await user.chat.openAwayFromMenu();
    await user.chat.awayDialog
      .getByTestId("away-message")
      .fill("Gone to lunch");
    await user.chat.awayDialog.getByRole("checkbox").first().click();
    await user.chat.awayDialog
      .getByRole("button", { name: "Set Away", exact: true })
      .click();
    await user.page.waitForTimeout(600);
    await shootWithBanner(user.page, user.chat.awayDialog, "away");
    await user.page.keyboard.press("Escape");
  });

  test("user modes", async () => {
    await user.chat.openUserModesFromMenu();
    await user.chat.userModesDialog.getByRole("checkbox").first().click();
    await user.chat.userModesDialog
      .getByRole("button", { name: "Apply", exact: true })
      .click();
    await user.page.waitForTimeout(600);
    await shootWithBanner(user.page, user.chat.userModesDialog, "user-modes");
    await user.page.keyboard.press("Escape");
  });

  test("alias editor", async () => {
    await user.chat.sendMessage("/alias add wave /me waves at everybody");
    await user.page.waitForTimeout(500);
    await user.chat.openAliasEditorFromMenu();
    await shootWithBanner(user.page, user.chat.aliasDialog, "alias");
    await user.page.keyboard.press("Escape");
  });

  test("autojoin", async () => {
    await user.chat.sendMessage(`/autojoin add ${channel}`);
    await user.page.waitForTimeout(500);
    await user.chat.openAutojoinDialogFromMenu();
    await shootWithBanner(user.page, user.chat.autojoinDialog, "autojoin");
    await user.page.keyboard.press("Escape");
  });

  test("perform", async () => {
    await user.chat.sendMessage("/perform add /msg NickServ info");
    await user.page.waitForTimeout(500);
    await user.chat.openPerformDialogFromMenu();
    await shootWithBanner(user.page, user.chat.performDialog, "perform");
    await user.page.keyboard.press("Escape");
  });

  test("auto respond", async () => {
    await user.chat.sendMessage(
      `/autorespond add on_join ${channel} /me waves at the new arrival`,
    );
    await user.page.waitForTimeout(600);
    await user.chat.openAutorespondDialogFromMenu();
    await shootWithBanner(
      user.page,
      user.chat.autorespondDialog,
      "auto-respond",
    );
    await user.page.keyboard.press("Escape");
  });

  test("timers", async () => {
    await user.chat.sendMessage("/timer nightly 3600 /me is still here");
    await user.page.waitForTimeout(500);
    await user.chat.openTimersFromToolsMenu();
    await shootWithBanner(user.page, user.chat.timersDialog, "timers");
    await user.page.keyboard.press("Escape");
  });

  test("highlight words", async () => {
    await user.chat.openHighlightDialogFromMenu();
    await user.chat.addHighlightWord("release", 4);
    await shootWithBanner(user.page, user.chat.highlightDialog, "highlight");
    await user.page.keyboard.press("Escape");
  });

  test("nick colors", async () => {
    await user.chat.openNickColorsFromMenu();
    await user.chat.nickColorsDialog
      .getByRole("button", { name: "Add" })
      .click();
    const addForm = user.page.getByTestId("nick-color-add-form");
    await expect(addForm).toBeVisible();
    await addForm.locator("#nick-color-add-nick").fill("Brutus");
    await user.chat.pickColor(addForm, 3);
    await addForm.getByRole("button", { name: "OK", exact: true }).click();
    await expect(addForm).toBeHidden();
    await shootWithBanner(user.page, user.chat.nickColorsDialog, "nick-colors");
    await user.page.keyboard.press("Escape");
  });

  test("sound settings", async () => {
    await user.chat.openSoundSettingsFromMenu();
    await shootWithBanner(
      user.page,
      user.chat.soundSettingsDialog,
      "sound-settings",
    );
    await user.page.keyboard.press("Escape");
  });

  test("flood protection", async () => {
    await user.chat.openFloodProtectionFromToolsMenu();
    await shootWithBanner(
      user.page,
      user.chat.floodProtectionDialog,
      "flood-protection",
    );
    await user.page.keyboard.press("Escape");
  });

  test("custom menus", async () => {
    await user.chat.openCustomMenusDialogFromMenu();
    await user.chat.addCustomMenuItem("Nicklist", "Slap", "/me slaps $1");
    await shootWithBanner(
      user.page,
      user.chat.customMenusDialog,
      "custom-menus",
    );
    await user.page.keyboard.press("Escape");
  });

  test("notify list", async () => {
    await user.chat.sendMessage("/notify add Brutus");
    await user.page.waitForTimeout(600);
    await user.chat.openNotifyListFromMenu();
    await shootWithBanner(user.page, user.chat.notifyListDialog, "notify-list");
    await user.page.keyboard.press("Escape");
  });

  test("address book", async () => {
    await user.chat.openAddressBookFromMenu();
    await user.chat.addAddressBookContact("Brutus", "runs the trivia night");
    await shootWithBanner(
      user.page,
      user.chat.addressBookDialog,
      "address-book",
    );
    await user.page.keyboard.press("Escape");
  });

  test("ignore list", async () => {
    await user.chat.sendMessage("/ignore Patches");
    await user.page.waitForTimeout(600);
    await user.chat.openIgnoreListFromMenu();
    await shootWithBanner(user.page, user.chat.ignoreListDialog, "ignore-list");
    await user.page.keyboard.press("Escape");
  });

  test("url catcher", async () => {
    await user.chat.sendMessage("have a look at https://example.com/retro");
    await user.page.waitForTimeout(800);
    await user.chat.openUrlCatcherFromMenu();
    await shootWithBanner(user.page, user.chat.urlCatcherDialog, "url-catcher");
    await user.page.keyboard.press("Escape");
  });

  test("saved messages", async () => {
    await user.chat.switchToTab(channel);
    await user.page.waitForTimeout(500);
    await user.chat.openMessageContextMenu("the rules live at");
    await user.page
      .getByTestId("context-menu-item-ctx_chat_save_message")
      .click();
    await user.page.waitForTimeout(800);

    await user.chat.openSavedFromStartMenu();
    await shootWithBanner(user.page, user.chat.savedDialog, "saved");
    await user.page.keyboard.press("Escape");
  });

  test("mentions", async () => {
    // Somebody else has to say the nickname: a window that answers "who said
    // my name" has nothing to draw until one of them does.
    // A mention is only unread if the reader was looking elsewhere, and the
    // tray badge only exists while one is unread.
    await user.chat.sendMessage("/join #gallery-elsewhere");
    await user.page.waitForTimeout(800);

    const other = await newSignedInUser(browserRef, "say", "pass12345");
    try {
      await other.chat.sendMessage(`/join ${channel}`);
      await other.page.waitForTimeout(800);
      await other.chat.sendMessage(`${user.nick} did you see the rules?`);
      await other.page.waitForTimeout(1500);
    } finally {
      await other.ctx.close();
    }

    await user.chat.openMentionsFromTray();
    await shootWithBanner(user.page, user.chat.mentionsDialog, "mentions");
    await user.page.keyboard.press("Escape");
  });

  test("pinned", async () => {
    // The mention shot moved the reader to another room; the Pinned button
    // belongs to whichever conversation is on screen.
    await user.chat.switchToTab(channel);
    await user.page.waitForTimeout(600);
    await user.chat.openPinnedFromToolbar();
    await shootWithBanner(user.page, user.chat.pinnedDialog, "pinned");
    await user.page.keyboard.press("Escape");
  });

  test("channel list", async () => {
    await user.chat.browseAllChannelsFromConversations();
    await shootWithBanner(
      user.page,
      user.chat.channelListDialog,
      "channel-list",
    );
    await user.chat.closeChannelList();
  });

  test("user lookup", async () => {
    await user.chat.openUserLookupFromToolsMenu();
    await user.chat.userLookupDialog
      .getByTestId("user-lookup-nickname")
      .fill(user.nick);
    await user.chat.userLookupDialog
      .getByRole("button", { name: "Whois", exact: true })
      .click();
    await user.page.waitForTimeout(900);
    await shootWithBanner(user.page, user.chat.userLookupDialog, "user-lookup");
    await user.page.keyboard.press("Escape");
  });

  test("events", async () => {
    await user.chat.switchToTab(channel);
    await user.page.waitForTimeout(400);
    await user.chat.sendMessage("/event 2h Tuesday tournament");
    await user.page.waitForTimeout(900);
    await user.chat.openEventsFromStartMenu();
    await shootWithBanner(user.page, user.chat.eventsDialog, "events");
    await user.page.keyboard.press("Escape");
  });

  test("thread", async () => {
    await user.chat.switchToTab(channel);
    await user.page.waitForTimeout(400);
    // Open Thread only appears once a line has an answer, which is the
    // point of the window.
    await user.chat.openMessageContextMenu("the rules live at");
    await user.page.getByTestId("context-menu-item-reply_to_message").click();
    await user.chat.sendMessage("they changed on Tuesday");
    await user.page.waitForTimeout(900);

    await user.chat.openMessageContextMenu("the rules live at");
    await user.page.getByTestId("context-menu-item-open_thread").click();
    await shootWithBanner(user.page, user.chat.threadDialog, "thread");
    await user.page.keyboard.press("Escape");
  });

  test("trusted terminals", async () => {
    // The list is empty for a browser that never asked to be remembered, so
    // the shot needs somebody who ticked the box at connect.
    const remembered = await browserRef.newContext();
    const page = await remembered.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    try {
      await connect.open();
      await connect.enterNickname(`Trust${Date.now().toString().slice(-5)}`);
      await page.getByTestId("remember-device").check();
      await connect.registerWithPassword("pass12345");
      await chat.waitUntilConnected();

      await chat.openTrustedTerminalsFromMenu();
      await shootWithBanner(
        page,
        chat.trustedTerminalsDialog,
        "trusted-terminals",
      );
    } finally {
      await remembered.close();
    }
  });

  test("trusted terminals, empty", async () => {
    await user.chat.openTrustedTerminalsFromMenu();
    await shootWithBanner(
      user.page,
      user.chat.trustedTerminalsDialog,
      "trusted-terminals-empty",
    );
    await user.page.keyboard.press("Escape");
  });

  test("channel central, every tab", async () => {
    await user.chat.openChannelCentralFromMenu();
    await shootWithBanner(
      user.page,
      user.chat.channelCentralDialog,
      "channel-central-general",
    );

    for (const tab of ["modes", "access_lists", "registration"] as const) {
      await user.chat.switchChannelCentralToTab(tab);
      await shootWithBanner(
        user.page,
        user.chat.channelCentralDialog,
        `channel-central-${tab}`,
        user.chat.channelCentralPanel(tab),
      );
    }

    await user.page.keyboard.press("Escape");
  });
});

/**
 * The windows only an administrator can open.
 *
 * Signed in as the account `config/e2e.exs` lists under `admins`, which
 * `ConnectPage.signIn` registers on first use — there is nothing to provision.
 *
 * Everything this block photographs it also creates, and the cleanup is not
 * optional: joining a channel while identified puts it on this account's
 * auto-join list, so a channel left behind is re-joined by every later login in
 * every later run.
 */
test.describe("dialog gallery, administrator", () => {
  test.describe.configure({ mode: "serial" });

  let admin: TestUser;
  let channel: string;
  let runningBot: string;
  let stoppedBot: string;
  const trigger = "rules";

  test.beforeAll(async ({ browser }) => {
    admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    channel = uniqueChannel("galbot");
    const suffix = Math.random().toString(36).slice(2, 7);
    runningBot = `galrun${suffix}`;
    stoppedBot = `galoff${suffix}`;

    await admin.chat.sendMessage(`/join ${channel}`);
    await admin.chat.expectTabVisible(channel);
    await admin.chat.switchToTab(channel);

    // Two bots, because the roster's picture is its lamps: one lit, one not.
    await admin.chat.sendMessage(
      `/bot create ${runningBot} Answers questions about the rules`,
    );
    await admin.chat.expectMessageVisible(
      `[BotService] Bot '${runningBot}' created successfully.`,
    );
    await admin.chat.sendMessage(`/bot join ${runningBot} ${channel}`);
    await admin.chat.expectMessageVisible(
      `[BotService] Bot '${runningBot}' joined ${channel}.`,
    );
    await admin.chat.sendMessage(
      `/bot addcmd ${runningBot} ${trigger} Read the topic, then say hello.`,
    );
    await admin.chat.expectMessageVisible(
      `[BotService] Command '${trigger}' set for ${runningBot}.`,
    );

    await admin.chat.sendMessage(
      `/bot create ${stoppedBot} Posts the weekly tournament bracket`,
    );
    await admin.chat.expectMessageVisible(
      `[BotService] Bot '${stoppedBot}' created successfully.`,
    );
    await admin.chat.sendMessage(`/bot disable ${stoppedBot}`);
    await admin.page.waitForTimeout(600);
  });

  test.afterAll(async () => {
    if (!admin) {
      return;
    }

    await admin.chat
      .sendMessage(`/bot part ${runningBot} ${channel}`)
      .catch(() => {});
    await admin.chat.sendMessage(`/bot destroy ${runningBot}`).catch(() => {});
    await admin.chat.sendMessage(`/bot destroy ${stoppedBot}`).catch(() => {});
    await admin.chat.sendMessage(`/autojoin remove ${channel}`).catch(() => {});
    await admin.chat.sendMessage(`/part ${channel}`).catch(() => {});
    await admin.ctx.close();
  });

  test("bot management roster", async () => {
    await admin.chat.openBotManagementFromToolsMenu();
    await expect(admin.chat.botList).toBeVisible();
    await shootWithBanner(
      admin.page,
      admin.chat.botManagementDialog,
      "bot-management-roster",
    );
  });

  test("new bot", async () => {
    await admin.chat.openNewBotDialog();
    await shootWithBanner(admin.page, admin.chat.newBotDialog, "bot-new");

    // A banner makes a form taller, and this one is a card inside a window
    // rather than over the viewport: the submit button is the first thing that
    // falls out the bottom, and a form you cannot submit is not a style
    // regression. Measured, because `toBeVisible` says nothing about whether
    // the window clipped it.
    await expectInsideWindow(
      admin.chat.newBotCreateButton,
      admin.chat.botManagementDialog,
    );

    await admin.chat.newBotCancelButton.click();
    await expect(admin.chat.newBotDialog).toBeHidden();
  });

  test("add command", async () => {
    await admin.chat.botItem(runningBot).click();
    await admin.page.getByTestId("bot-back").waitFor();
    // The tab strip is a row of buttons carrying `data-target`, not ARIA tabs.
    await admin.chat.botManagementDialog
      .locator('button[data-target="commands"]')
      .click();
    await admin.chat.botManagementDialog
      .getByRole("button", { name: "Add", exact: true })
      .click();
    await expect(admin.chat.addCommandDialog).toBeVisible();
    await shootWithBanner(
      admin.page,
      admin.chat.addCommandDialog,
      "bot-add-command",
    );
    await admin.chat.addCommandDialog
      .getByRole("button", { name: "Cancel" })
      .click();
    await admin.chat.closeBotManagementDialog();
  });

  // There is no slash command for this: an emoji is a picture, so it is added
  // from the window, which is the only place that can take a file.
  test("server emoji", async () => {
    const name = `gal${Math.random().toString(36).slice(2, 7)}`;

    await admin.chat.openServerEmojiFromMenu();
    const window = admin.chat.serverEmojiDialog;

    await window.locator('input[type="file"]').setInputFiles({
      name: `${name}.png`,
      mimeType: "image/png",
      buffer: ONE_PIXEL_PNG,
    });
    await window.getByTestId("server-emoji-name").fill(name);
    await window.getByTestId("server-emoji-submit").click();
    await expect(window.getByTestId(`server-emoji-row-${name}`)).toBeVisible();

    await shootWithBanner(admin.page, window, "server-emoji");

    await window.getByTestId(`server-emoji-remove-${name}`).click();
    await expect(window.getByTestId(`server-emoji-row-${name}`)).toBeHidden();
    await admin.page.keyboard.press("Escape");
  });

  // The nine focused admin windows. `openAdminWindow` returns the panel, which
  // is the scope the banner is looked for in — the window frame also carries
  // the title bar, and a tabbed neighbour could put a second banner in reach.
  const adminWindow = async (action: string) => {
    const panel = await admin.chat.openAdminWindow(action);
    const window = admin.page.getByTestId(
      `${action.replace(/^open_/, "").replaceAll("_", "-")}-window`,
    );
    return { panel, window };
  };

  test("admin users", async () => {
    const { panel, window } = await adminWindow("open_admin_users");
    await expect(panel.getByTestId("admin-users-table")).toBeVisible();
    await shootWithBanner(admin.page, window, "admin-users", panel);
    await admin.page.keyboard.press("Escape");
  });

  test("admin channels", async () => {
    const { panel, window } = await adminWindow("open_admin_channels");
    await admin.page.waitForTimeout(600);
    await shootWithBanner(admin.page, window, "admin-channels", panel);
    await admin.page.keyboard.press("Escape");
  });

  test("admin server settings", async () => {
    const { panel, window } = await adminWindow("open_admin_server_settings");
    await admin.page.waitForTimeout(600);
    await shootWithBanner(admin.page, window, "admin-server-settings", panel);
    await admin.page.keyboard.press("Escape");
  });

  test("admin audit log", async () => {
    const { panel, window } = await adminWindow("open_admin_audit_log");
    await admin.page.waitForTimeout(800);
    await shootWithBanner(admin.page, window, "admin-audit-log", panel);
    await admin.page.keyboard.press("Escape");
  });

  // Set, photograph, clear: an MOTD left behind is printed to every later
  // spec's connect, and a spec that asserts on the Status window would read it.
  test("admin motd", async () => {
    const { panel, window } = await adminWindow("open_admin_motd");
    await panel
      .locator("#admin-motd-input")
      .fill("Arcade night is Thursday. Be kind in #lobby.");
    await panel.getByRole("button", { name: "Set MOTD" }).click();
    await expect(panel.locator("#admin-motd-current")).toContainText(
      "Arcade night",
    );

    await shootWithBanner(admin.page, window, "admin-motd", panel);

    await panel.getByRole("button", { name: "Clear MOTD" }).click();
    await expect(panel.locator("#admin-motd-current")).toContainText(
      "No MOTD has been set.",
    );
    await admin.page.keyboard.press("Escape");
  });

  test("admin turn", async () => {
    const { panel, window } = await adminWindow("open_admin_turn");
    await admin.page.waitForTimeout(600);
    await shootWithBanner(admin.page, window, "admin-turn", panel);
    await admin.page.keyboard.press("Escape");
  });

  test("admin broadcast", async () => {
    const { panel, window } = await adminWindow("open_admin_broadcast");
    await shootWithBanner(admin.page, window, "admin-broadcast", panel);
    await admin.page.keyboard.press("Escape");
  });

  test("admin danger zone", async () => {
    const { panel, window } = await adminWindow("open_admin_danger_zone");
    await admin.page.waitForTimeout(600);
    await shootWithBanner(admin.page, window, "admin-danger-zone", panel);
    await admin.page.keyboard.press("Escape");
  });

  test("admin console", async () => {
    const { panel, window } = await adminWindow("open_admin_console");
    await panel.locator("#admin-console-input").fill("/admin");
    await panel.getByRole("button", { name: "Run" }).click();
    await expect(panel.getByTestId("admin-console-output")).not.toBeEmpty();
    await admin.page.waitForTimeout(400);
    await shootWithBanner(admin.page, window, "admin-console", panel);
    await admin.page.keyboard.press("Escape");
  });
});

/**
 * The confirmation tier: windows that interrupt to ask one thing.
 *
 * These carry no banner. A wizard band between the question and the buttons
 * delays an answer the reader already has in mind, so they get the Win98
 * message box instead — a 32×32 glyph of the subject, the question, and what
 * follows from saying yes.
 *
 * Three of the family are not here. Kicked from Channel needs an operator to
 * remove this session from a room, and the two call confirmations need a peer
 * on the other end of a real connection; neither is a browser gesture a
 * gallery can make on its own.
 */
test.describe("dialog gallery, confirmations", () => {
  test.describe.configure({ mode: "serial" });

  let user: TestUser;
  let other: TestUser;
  let channel: string;
  let takenNick: string;

  // Whichever dialog surface is on screen. The ids differ per dialog and the
  // wrappers collapse to nothing when closed, so the shape is the handle.
  const onScreen = (page: Page) =>
    page.locator('[id$="-surface"]:visible').first();

  async function shootMessage(page: Page, name: string) {
    const surface = onScreen(page);
    await expect(
      surface.locator("[data-dialog-message]").first(),
    ).toBeVisible();
    await page.waitForTimeout(300);
    await surface.screenshot({ path: `${SHOTS}/${name}.png` });
  }

  test.beforeAll(async ({ browser }) => {
    user = await newSignedInUser(browser, "cfm", "pass12345");
    other = await newSignedInUser(browser, "cfo", "pass12345");
    channel = uniqueChannel("confirm");

    await user.chat.sendMessage(`/join ${channel}`);
    await user.chat.expectTabVisible(channel);
    await user.chat.sendMessage("/cs register");
    await user.page.waitForTimeout(800);

    await other.chat.sendMessage(`/join ${channel}`);
    await other.chat.expectTabVisible(channel);
    await user.chat.expectNickInList(other.nick);

    // A nickname that is registered to somebody and is not currently held,
    // which is the only case the Change Nickname dialog is about.
    // Photographing it with a free name let the change go through, and the
    // session lost its identification for every test after it.
    const spare = await newSignedInUser(browser, "cfs", "pass12345");
    takenNick = spare.nick;
    await spare.ctx.close();
  });

  test.afterAll(async () => {
    await user?.ctx.close();
    await other?.ctx.close();
  });

  test("delete a message", async () => {
    await user.chat.switchToTab(channel);
    await user.chat.sendMessage("that came out wrong");
    await user.chat.openMessageContextMenu("that came out wrong");
    await user.chat.contextDeleteMenuItem.click();
    await shootMessage(user.page, "confirm-delete");
    await user.page.keyboard.press("Escape");
  });

  test("follow a link out of the app", async () => {
    await user.chat.sendMessage(
      "the schedule is at https://example.com/nights",
    );
    await user.page.waitForTimeout(500);
    await user.page
      .locator('[data-testid="chat-message-list"] a[href*="example.com"]')
      .first()
      .click();
    await expect(
      user.page.getByTestId("open-tab-confirm-message"),
    ).toBeVisible();
    await shootMessage(user.page, "confirm-open-tab");
    await user.page.getByTestId("open-tab-confirm-cancel").click();
  });

  test("send a pasted block", async () => {
    await user.chat.pasteText(
      Array.from({ length: 12 }, (_, i) => `line ${i + 1}`).join("\n"),
    );
    await expect(user.chat.pasteConfirmSendButton).toBeVisible();
    await shootMessage(user.page, "confirm-paste");
    await user.chat.pasteConfirmCancelButton.click();
  });

  test("take a registered nickname", async () => {
    await user.chat.sendMessage(`/nick ${takenNick}`);
    await expect(user.chat.nickChangeDialog).toBeVisible();
    await shootMessage(user.page, "confirm-nick-change");
    await user.chat.nickChangeCancelButton.click();
  });

  test("mute somebody", async () => {
    await user.chat.switchToTab(channel);
    await user.chat.openNicklistContextMenu(other.nick);
    await user.page.getByTestId("context-menu-item-context_mute").click();
    await expect(user.chat.muteDurationDialog).toBeVisible();
    await shootMessage(user.page, "confirm-mute-duration");
    await user.page.keyboard.press("Escape");
  });

  test("invite somebody into a room", async () => {
    const second = uniqueChannel("cfinv");
    await user.chat.sendMessage(`/join ${second}`);
    await user.chat.expectTabVisible(second);
    await user.chat.switchToTab(channel);

    await user.chat.openNicklistContextMenu(other.nick);
    await user.page
      .getByTestId("context-menu-item-context_invite_to_channel")
      .click();
    await expect(user.chat.inviteChannelPickerDialog).toBeVisible();
    await shootMessage(user.page, "confirm-invite-picker");
    await user.page.keyboard.press("Escape");
    await user.chat.sendMessage(`/part ${second}`);
    await user.chat.expectTabHidden(second);
  });

  test("ask to be let into a closed room", async () => {
    await user.chat.switchToTab(channel);
    await user.chat.sendMessage("/mode +i");
    await user.page.waitForTimeout(600);

    await other.chat.sendMessage(`/part ${channel}`);
    await other.page.waitForTimeout(500);
    await other.chat.browseAllChannelsFromConversations();
    await expect(other.chat.channelListRowAction(channel)).toHaveText(
      "Request Access...",
    );
    await other.chat.channelListRow(channel).click();
    await expect(other.chat.knockRequestDialog).toBeVisible();
    await shootMessage(other.page, "confirm-knock-request");
    await other.page.keyboard.press("Escape");

    await user.chat.sendMessage("/mode -i");
  });

  test("disconnect from the server", async () => {
    await other.chat.openFileMenu();
    await expect(other.chat.disconnectMenuItem).toBeVisible();
    await other.chat.disconnectMenuItem.click();
    await expect(other.chat.disconnectConfirmButton).toBeVisible();
    await shootMessage(other.page, "confirm-disconnect");
    await other.page.keyboard.press("Escape");
  });
});
