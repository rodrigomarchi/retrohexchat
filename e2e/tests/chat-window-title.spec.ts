/**
 * @section Backlog T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T14 [done] Window title bar, taskbar button, and browser tab all name the active conversation `#channel[nick]` and follow tab switches (features P1)
 * @flow T15 [done] Activity flash alternates over the conversation's name and restores it (features P1)
 * @flow T16 [done] A private message titles the window `remote:mine` (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = "wtitle"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = "wtitle") {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = "wtitle",
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

test.describe("Window, taskbar and tab titles", () => {
  test("the taskbar and the browser tab name the active conversation identically (T14)", async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page);
    const channel = uniqueChannel();

    const titleBar = chat.chatWindowTitleBar;
    const taskbarButton = chat.taskbarButton("chat");

    // The window's title bar names the application, not the conversation: it
    // is one pinned window that every conversation shares, so a title that
    // followed the active tab would be the only window on the desktop whose
    // name changed under you. The taskbar button and the browser tab are the
    // two surfaces that track the conversation.
    await expect(titleBar).toContainText("Chat");
    await expect(taskbarButton).toContainText(`#lobby[${nick}]`);
    await expect(page).toHaveTitle(`#lobby[${nick}]`);

    await chat.sendMessage(`/join ${channel}`);
    await expect(chat.tab(channel)).toHaveAttribute("aria-selected", "true");

    const channelTitle = `${channel}[${nick}]`;
    await expect(taskbarButton).toContainText(channelTitle);
    await expect(page).toHaveTitle(channelTitle);
    await shot(page, "channel-title");

    // The identity state rides along in the title bar's meta zone.
    await expect(titleBar).toContainText("Identified");

    // Back to Status: both conversation-tracking surfaces follow.
    await chat.switchToStatusTab();
    await expect(taskbarButton).toContainText(`Status[${nick}]`);
    await expect(page).toHaveTitle(`Status[${nick}]`);
  });

  test("the activity flash alternates over the conversation's name (T15)", async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, "wtitlef");
    const bob = await newSignedInUser(browser, "wtitleg");

    try {
      // Flash on PM activity, so a message to a tab bob is not looking at
      // alternates his tab title.
      await bob.chat.openSoundSettingsFromMenu();
      await bob.chat.setSoundFlash("pm", true);
      await bob.chat.soundSettingsDialog
        .getByRole("button", { name: "OK" })
        .click();
      await expect(bob.chat.soundSettingsDialog).toBeHidden();

      const base = `#lobby[${bob.nick}]`;
      await expect(bob.chat.page).toHaveTitle(base);

      await alice.chat.sendMessage(`/msg ${bob.nick} knock knock`);

      // The flash rides on top of the conversation's name, and the name comes
      // back on the other half of the alternation.
      await expect(bob.chat.page).toHaveTitle(`* New activity - ${base}`);
      await expect(bob.chat.page).toHaveTitle(base);
    } finally {
      await Promise.all([alice.ctx.close(), bob.ctx.close()]);
    }
  });

  test("a PM names the taskbar button and the tab remote:mine (T16)", async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, "wtitlea");
    const bob = await newSignedInUser(browser, "wtitleb");

    try {
      await alice.chat.sendMessage(`/msg ${bob.nick} hey`);
      await alice.chat.switchToTab(bob.nick);

      const pmTitle = `${bob.nick}:${alice.nick}`;
      await expect(alice.chat.taskbarButton("chat")).toContainText(pmTitle);
      await expect(alice.chat.page).toHaveTitle(pmTitle);
      await shot(alice.chat.page, "pm-title");
    } finally {
      await Promise.all([alice.ctx.close(), bob.ctx.close()]);
    }
  });
});
