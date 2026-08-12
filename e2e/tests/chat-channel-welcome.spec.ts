/**
 * @section H - Channels, Server Messages, Local Window State
 * @flow H9 [done] `/setwelcome` shows welcome once for a later joiner (features P1)
 * @flow H10 [done] `/clearwelcome` stops welcome for later joiners (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

function uniqueChannel(prefix = "welcome"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: import("@playwright/test").Page,
  prefix = "e2e",
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();
  return { chat, nick };
}

async function setupOwnerAndJoiner(browser: Browser) {
  const ownerContext = await browser.newContext();
  const joinerContext = await browser.newContext();
  const ownerPage = await ownerContext.newPage();
  const joinerPage = await joinerContext.newPage();

  const owner = await signedInUser(ownerPage, "owner");
  const joiner = await signedInUser(joinerPage, "joiner");

  return {
    ownerContext,
    joinerContext,
    ownerChat: owner.chat,
    joinerChat: joiner.chat,
  };
}

test.describe("Channel welcome messages", () => {
  test("/setwelcome shows a channel welcome once per joiner session (H9)", async ({
    browser,
  }) => {
    const channel = uniqueChannel("welcome");
    const welcome = `Welcome once ${Date.now()}`;
    const { ownerContext, joinerContext, ownerChat, joinerChat } =
      await setupOwnerAndJoiner(browser);

    try {
      await ownerChat.sendMessage(`/join ${channel}`);
      await ownerChat.expectTabVisible(channel);
      await ownerChat.sendMessage(`/setwelcome ${welcome}`);
      await ownerChat.expectMessageVisible(
        `Welcome message for ${channel} has been set.`,
      );

      // Something stored, so that rejoining below has real history to show and
      // "the welcome is not there" cannot be satisfied by an empty channel.
      const stored = `stored history ${Date.now()}`;
      await ownerChat.sendMessage(stored);

      await joinerChat.sendMessage(`/join ${channel}`);
      await joinerChat.expectTabVisible(channel);
      await joinerChat.expectMessageVisible(`[Welcome] ${welcome}`);
      const welcomeMessages = joinerChat.messageList
        .locator("[data-message-id]")
        .filter({ hasText: `[Welcome] ${welcome}` });
      await expect(welcomeMessages).toHaveCount(1);

      // Rejoining must not greet the same person twice. The greeting is said to
      // a person, not written to the channel, so it is not in the history the
      // rejoin loads — the stored message is, which is what proves the channel
      // really came back rather than the assertion passing on an empty view.
      await joinerChat.sendMessage(`/part ${channel}`);
      await joinerChat.expectTabHidden(channel);
      await joinerChat.sendMessage(`/join ${channel}`);
      await joinerChat.expectTabVisible(channel);
      await joinerChat.expectMessageVisible(stored);
      await expect(welcomeMessages).toHaveCount(0);
    } finally {
      await ownerContext.close();
      await joinerContext.close();
    }
  });

  test("/clearwelcome stops the channel welcome for later joiners (H10)", async ({
    browser,
  }) => {
    const channel = uniqueChannel("clearwelcome");
    const welcome = `Cleared welcome ${Date.now()}`;
    const { ownerContext, joinerContext, ownerChat, joinerChat } =
      await setupOwnerAndJoiner(browser);

    try {
      await ownerChat.sendMessage(`/join ${channel}`);
      await ownerChat.expectTabVisible(channel);
      await ownerChat.sendMessage(`/setwelcome ${welcome}`);
      await ownerChat.expectMessageVisible(
        `Welcome message for ${channel} has been set.`,
      );

      await ownerChat.sendMessage("/clearwelcome");
      await ownerChat.expectMessageVisible(
        `Welcome message for ${channel} has been cleared.`,
      );

      await joinerChat.sendMessage(`/join ${channel}`);
      await joinerChat.expectTabVisible(channel);
      await joinerChat.expectMessageHidden(`[Welcome] ${welcome}`);
    } finally {
      await ownerContext.close();
      await joinerContext.close();
    }
  });
});
