/**
 * @section W - Presence, Identity, Nick Changes, Whois/Whowas
 * @flow W18 [done] Everybody's nickname carries the flag of the language they use the chat in: the user list, their lines, the hover card and a private conversation's row and tab, on a desktop and on a phone
 * @flow W19 [done] A visitor watching without an account is listed under Visitors with the flag of the language the chat is shown to them in
 * @flow W20 [done] The tools that list people draw the same flag: autocomplete, whois, the address book, notify list, nick colours, ignore list, URL catcher, mentions, pinned lines, Channel Central and a private conversation's typing line
 * @flow W21 [done] A channel's founder sets the language it is spoken in with /cs language or Channel Central's Registration tab, and its flag is drawn beside the channel's name: the tab, the topic bar, the conversations list, the channel list and the public archive, on a desktop and on a phone
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, Page, expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { closeUsers, uniqueChannel, type TestUser } from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";

const PHONE = { viewport: { width: 390, height: 844 }, hasTouch: true };

// A member who opened the chat in `locale`: the language is the address's, so
// signing in from the localized Connect window is all it takes.
async function signedInIn(
  browser: Browser,
  prefix: string,
  locale: string,
  options = {},
): Promise<TestUser> {
  const ctx = await browser.newContext(options);
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open(locale);
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password: "pass12345" };
}

function flagOf(scope: Page | ReturnType<Page["locator"]>, locale: string) {
  return scope.locator(`[data-testid="nick-flag"][data-locale="${locale}"]`);
}

// The head of the last line `nick` wrote: the portrait, the flag and the name.
function lastLineHead(page: Page, nick: string) {
  return page
    .locator(".chat-message__head", {
      has: page.locator(`.chat-message__author[data-nick="${nick}"]`),
    })
    .last();
}

test.describe("Language flags beside nicknames", () => {
  test("every nickname carries its person's language flag (W18)", async ({
    browser,
  }) => {
    const alice = await signedInIn(browser, "w18a", "pt_BR");
    const kenji = await signedInIn(browser, "w18k", "ja");
    const channel = uniqueChannel("flags");

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await kenji.chat.sendMessage(`/join ${channel}`);
      await kenji.chat.expectTabVisible(channel);
      await kenji.chat.sendMessage("konnichiwa");
      await alice.chat.sendMessage("olá a todos");

      // The user list: each row's flag is that person's own language.
      await alice.chat.expectNickInList(kenji.nick);
      await expect(
        flagOf(alice.chat.nicklistItem(kenji.nick), "ja"),
      ).toBeVisible();
      await expect(
        flagOf(alice.chat.nicklistItem(alice.nick), "pt_BR"),
      ).toBeVisible();
      await expect(
        flagOf(alice.chat.nicklistItem(kenji.nick), "ja"),
      ).toHaveAttribute("title", "日本語");
      await shot(alice.page, "desktop-channel");
      await shot(alice.chat.nicklist, "user-list-flags");

      // Their lines: the flag sits between the portrait and the name.
      await expect(
        flagOf(lastLineHead(alice.page, kenji.nick), "ja"),
      ).toBeVisible();
      await expect(
        flagOf(lastLineHead(alice.page, alice.nick), "pt_BR"),
      ).toBeVisible();
      await shot(lastLineHead(alice.page, kenji.nick), "message-line-flag");

      // The other screen draws the same flags, read the other way round.
      await expect(
        flagOf(kenji.chat.nicklistItem(alice.nick), "pt_BR"),
      ).toBeVisible();
      await shot(kenji.page, "desktop-channel-in-japanese");

      // The hover card names the language in itself.
      await alice.chat.nicklistItem(kenji.nick).hover();
      const card = alice.page.getByTestId("hover-card-locale");
      await expect(card).toContainText("日本語");
      await shot(
        alice.page.getByTestId(`hover-card-${kenji.nick}`),
        "hover-card",
      );

      // A private conversation: its row in the sidebar and its tab.
      await alice.chat.sendMessage(`/msg ${kenji.nick} oi`);
      await alice.chat.expectTabVisible(kenji.nick);
      await alice.chat.switchToTab(kenji.nick);
      await expect(
        flagOf(alice.page.getByTestId(`pm-${kenji.nick}`), "ja"),
      ).toBeVisible();
      await expect(
        flagOf(alice.page.getByTestId("tab-bar"), "ja"),
      ).toBeVisible();
      await shot(alice.page, "private-conversation");
    } finally {
      await closeUsers([alice, kenji]);
    }

    // On a phone the line keeps its flag at the same size.
    const phone = await signedInIn(browser, "w18p", "es", PHONE);
    try {
      await phone.chat.sendMessage("hola");
      await expect(
        flagOf(lastLineHead(phone.page, phone.nick), "es"),
      ).toBeVisible();
      await shot(phone.page, "phone-line");
    } finally {
      await closeUsers([phone]);
    }
  });

  test("a visitor is listed with the flag of the language they read in (W19)", async ({
    browser,
  }) => {
    const member = await signedInIn(browser, "w19m", "en");
    const visitorCtx = await browser.newContext();
    const visitor = await visitorCtx.newPage();

    try {
      await visitor.addInitScript(() => {
        try {
          window.localStorage.setItem("retro_hex_chat_tips_suppressed", "true");
        } catch {
          /* localStorage unavailable — the tips only overlay */
        }
      });
      await visitor.goto("/es");
      await expect(visitor.getByTestId("visitor-composer")).toBeVisible();

      const own = visitor.locator(
        '[data-testid^="nicklist-guest-"][data-current="true"]',
      );
      const guestName = (await own.innerText()).trim();
      await expect(flagOf(own, "es")).toBeVisible();
      await shot(visitor, "visitor-sees-own-flag");

      // A member of the lobby sees the same flag in front of the guest name.
      await member.chat.expectTabVisible("#lobby");
      const row = member.page.getByTestId(`nicklist-guest-${guestName}`);
      await expect(flagOf(row, "es")).toBeVisible();
      await shot(member.chat.nicklist, "member-sees-visitor-flag");
    } finally {
      await closeUsers([member]);
      await visitorCtx.close();
    }
  });

  test("the tools that list people draw the same flag (W20)", async ({
    browser,
  }) => {
    const alice = await signedInIn(browser, "w20a", "en");
    const kenji = await signedInIn(browser, "w20k", "ja");
    const channel = uniqueChannel("ftour");
    const page = alice.page;
    const kenjiFlag = (scope: Page | ReturnType<Page["locator"]>) =>
      flagOf(scope, "ja").first();
    const closeWindows = () => page.keyboard.press("Escape");

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await kenji.chat.sendMessage(`/join ${channel}`);
      await kenji.chat.expectTabVisible(channel);
      // Mentioned while reading elsewhere: the mention waits in the tray.
      await alice.chat.switchToTab("#lobby");
      await kenji.chat.sendMessage(
        `${alice.nick} see https://example.test/flags`,
      );
      await alice.chat.openMentionsFromTray();
      await expect(kenjiFlag(alice.chat.mentionsDialog)).toBeVisible();
      await shot(alice.chat.mentionsDialog, "mentions-window");
      await closeWindows();
      await alice.chat.switchToTab(channel);
      await expect(alice.chat.messageList).toContainText("example.test/flags");
      await alice.chat.expectNickInList(kenji.nick);

      // Autocomplete offers the nickname with its flag.
      await alice.chat.chatInput.click();
      await alice.chat.chatInput.pressSequentially(
        `@${kenji.nick.slice(0, 4)}`,
      );
      await expect(kenjiFlag(alice.chat.autocompleteDropdown)).toBeVisible();
      await shot(alice.chat.autocompleteDropdown, "autocomplete");
      await alice.chat.chatInput.fill("");

      // Whois: the flag in front of the nickname row.
      await alice.chat.sendMessage(`/whois ${kenji.nick}`);
      await alice.chat.expectWhoisCard(kenji.nick);
      await expect(kenjiFlag(alice.chat.lookupResultCard)).toBeVisible();
      await shot(alice.chat.lookupResultCard, "whois-card");
      await closeWindows();

      // Pinned: the owner pins Kenji's line from its menu.
      await alice.chat.openMessageContextMenu("example.test/flags");
      await page.getByTestId("context-menu-item-ctx_chat_pin_message").click();
      await alice.chat.openPinnedFromToolbar();
      await expect(kenjiFlag(alice.chat.pinnedDialog)).toBeVisible();
      await shot(alice.chat.pinnedDialog, "pinned-window");
      await closeWindows();

      // URL catcher.
      await alice.chat.openUrlCatcherFromMenu();
      await expect(kenjiFlag(alice.chat.urlCatcherDialog)).toBeVisible();
      await shot(alice.chat.urlCatcherDialog, "url-catcher-window");
      await closeWindows();

      // Channel Central names who set the topic, with a flag; Alice is English.
      await alice.chat.sendMessage("/topic flags of the world");
      await alice.chat.openChannelCentralFromMenu();
      await expect(
        flagOf(alice.chat.channelCentralDialog, "en").first(),
      ).toBeVisible();
      await shot(alice.chat.channelCentralDialog, "channel-central-window");
      await closeWindows();

      // Address book, notify list and nick colours.
      await alice.chat.openAddressBookFromMenu();
      await alice.chat.addAddressBookContact(kenji.nick, "tokyo");
      await expect(kenjiFlag(alice.chat.addressBookDialog)).toBeVisible();
      await shot(alice.chat.addressBookDialog, "address-book-window");
      await closeWindows();

      await alice.chat.sendMessage(`/notify add ${kenji.nick}`);
      await alice.chat.openNotifyListFromMenu();
      await expect(kenjiFlag(alice.chat.notifyListDialog)).toBeVisible();
      await shot(alice.chat.notifyListDialog, "notify-list-window");
      await closeWindows();

      await alice.chat.addAddressBookNickColor(kenji.nick, 4);
      await expect(kenjiFlag(alice.chat.nickColorsDialog)).toBeVisible();
      await shot(alice.chat.nickColorsDialog, "nick-colors-window");
      await closeWindows();

      // A private conversation: Kenji typing shows his flag in front of it.
      await alice.chat.sendMessage(`/msg ${kenji.nick} oi`);
      await alice.chat.switchToTab(kenji.nick);
      await kenji.chat.expectTabVisible(alice.nick);
      await kenji.chat.switchToTab(alice.nick);
      await kenji.chat.chatInput.click();
      await kenji.chat.chatInput.pressSequentially("tadaima", { delay: 50 });
      const typing = page.getByTestId("typing-indicator");
      await expect(kenjiFlag(typing)).toBeVisible();
      await shot(typing, "typing-indicator");

      // Ignore list last: ignoring hides what Kenji says.
      await alice.chat.sendMessage(`/ignore ${kenji.nick}`);
      await alice.chat.openIgnoreListFromMenu();
      await expect(kenjiFlag(alice.chat.ignoreListDialog)).toBeVisible();
      await shot(alice.chat.ignoreListDialog, "ignore-list-window");
    } finally {
      await closeUsers([alice, kenji]);
    }
  });

  test("a channel's founder gives it a language and its flag follows the name (W21)", async ({
    browser,
  }) => {
    const alice = await signedInIn(browser, "w21a", "pt_BR");
    const channel = uniqueChannel("idioma");
    const slug = channel.slice(1);
    const page = alice.page;
    const channelFlag = (
      scope: Page | ReturnType<Page["locator"]>,
      locale: string,
    ) => scope.locator(`[data-testid="channel-flag"][data-locale="${locale}"]`);

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.sendMessage("/cs register");
      await alice.chat.sendMessage("/cs archive on");

      // Nobody chose yet: no flag beside the name.
      await expect(
        page.getByTestId("tab-bar").getByTestId("channel-flag"),
      ).toHaveCount(0);

      // The command, written loosely.
      await alice.chat.sendMessage("/cs language pt-br");
      await expect(
        channelFlag(page.getByTestId("tab-bar"), "pt_BR"),
      ).toBeVisible();
      await expect(
        channelFlag(page.getByTestId("topic-bar"), "pt_BR"),
      ).toBeVisible();
      await expect(
        channelFlag(page.getByTestId(`channel-${channel}`), "pt_BR"),
      ).toBeVisible();
      await shot(page, "channel-language-desktop");
      await shot(page.getByTestId("topic-bar"), "topic-bar-flag");
      await shot(
        page.getByTestId(`channel-${channel}`),
        "conversations-row-flag",
      );

      // Channel Central: the founder's select changes it. Opened from the
      // conversation bar, which reads the same in every language.
      await page.getByTestId("conversation-toolbar-channel-central").click();
      await expect(alice.chat.channelCentralDialog).toBeVisible();
      await alice.chat.switchChannelCentralToTab("registration");
      const control = page.getByTestId("cc-language-switch");
      await expect(control).toBeVisible();
      await expect(channelFlag(control, "pt_BR")).toBeVisible();
      await shot(alice.chat.channelCentralDialog, "channel-central-language");

      await control.locator(".retro-combo").click();
      await shot(
        alice.chat.channelCentralDialog,
        "channel-central-language-open",
      );
      await page
        .locator("#cc-language-select-content label[role=option]", {
          hasText: "日本語",
        })
        .click();
      await expect(channelFlag(control, "ja")).toBeVisible();
      await expect(
        channelFlag(page.getByTestId("tab-bar"), "ja"),
      ).toBeVisible();
      await page.keyboard.press("Escape");

      // The channel list draws it beside the room's name.
      await alice.chat.sendMessage("/list");
      await expect(alice.chat.channelListDialog).toBeVisible();
      await expect(
        channelFlag(alice.chat.channelListRow(channel), "ja"),
      ).toBeVisible();
      await shot(alice.chat.channelListDialog, "channel-list-flag");
      await alice.chat.closeChannelList();

      // The public archive's heading.
      await alice.chat.sendMessage("said in a room that speaks Japanese");
      const reader = await alice.ctx.newPage();
      await reader.goto(`/archive/${slug}`);
      await expect(
        channelFlag(reader.locator("#archive-heading"), "ja"),
      ).toBeVisible();
      await shot(reader, "archive-index-flag");
      await reader.close();
    } finally {
      await closeUsers([alice]);
    }

    // On a phone the tab and the topic bar keep the flag at the same size.
    const phone = await signedInIn(browser, "w21p", "en", PHONE);
    try {
      await phone.chat.sendMessage(`/join ${channel}`);
      await phone.chat.expectTabVisible(channel);
      await expect(
        channelFlag(phone.page.getByTestId("tab-bar"), "ja"),
      ).toBeVisible();
      await shot(phone.page, "channel-language-phone");
    } finally {
      await closeUsers([phone]);
    }
  });
});
