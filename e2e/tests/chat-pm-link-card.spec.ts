/**
 * @section O - Chat UI Micro-Journeys
 * @flow O27 [done] A link in the first private message is captured and carded on both sides, once
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { e2eURL } from "../helpers/env";

async function signedInUser(page: Page, prefix: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();
  return { chat, nick };
}

test.describe("Private message link card", () => {
  // Two defects met here. The sender was never on its own conversation's topic,
  // so nothing the broadcast drives ever ran for it; and the recipient joined
  // that topic *because of* the first message, which therefore could not be
  // delivered on it. Between them, a link in a private message was captured for
  // nobody. The counts are the other half: subscribing is not idempotent, so a
  // reader who walked into the conversation four times used to file every
  // later link four times.
  test("captured and carded for both sides, exactly once (O27)", async ({
    browser,
  }) => {
    test.setTimeout(180_000);
    const ctxA = await browser.newContext();
    const ctxB = await browser.newContext();
    const pageA = await ctxA.newPage();
    const pageB = await ctxB.newPage();

    try {
      const { chat: chatA, nick: nickA } = await signedInUser(pageA, "pma");
      const { chat: chatB, nick: nickB } = await signedInUser(pageB, "pmb");
      const first = e2eURL(`/?pm=${Date.now()}`);

      await chatA.sendMessage(`/msg ${nickB} olha isso ${first}`);
      await chatB.switchToTab(nickA);
      await chatB.expectMessageVisible(first);

      await expect(
        chatB.messageRowByText(first).locator(".chat-link-card"),
      ).toBeVisible({ timeout: 30_000 });

      // `/msg` sends without opening the query, so the sender walks in to look.
      await chatA.switchToTab(nickB);
      await expect(
        chatA.messageRowByText(first).locator(".chat-link-card"),
      ).toBeVisible({ timeout: 30_000 });

      await chatB.switchToStatusTab();
      await chatB.switchToTab(nickA);
      await chatB.switchToStatusTab();
      await chatB.switchToTab(nickA);

      const second = e2eURL(`/?pm2=${Date.now()}`);
      await chatA.sendMessage(`segunda ${second}`);
      await chatB.expectMessageVisible(second);

      await chatA.openUrlCatcherFromMenu();
      const sender = await chatA.urlCatcherRows.allInnerTexts();
      await chatB.openUrlCatcherFromMenu();
      const receiver = await chatB.urlCatcherRows.allInnerTexts();

      for (const url of [first, second]) {
        expect(sender.filter((row) => row.includes(url))).toHaveLength(1);
        expect(receiver.filter((row) => row.includes(url))).toHaveLength(1);
      }
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
