/**
 * @section S - Message Lifecycle Additions
 * @flow S14 [done] A message that was answered counts its replies and opens them together, while every reply stays in the room (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test.describe("Threads", () => {
  test("a thread counts its replies, opens them together, and leaves them in the room (S14)", async ({
    browser,
  }) => {
    const ctxAsker = await browser.newContext();
    const ctxAnswerer = await browser.newContext();
    const pageAsker = await ctxAsker.newPage();
    const pageAnswerer = await ctxAnswerer.newPage();

    const channel = `#thr${Math.random().toString(36).slice(2, 8)}`;
    const askerNick = uniqueNickname("ask");
    const answererNick = uniqueNickname("ans");

    try {
      const askerConnect = new ConnectPage(pageAsker);
      const asker = new ChatPage(pageAsker);
      await askerConnect.open();
      await askerConnect.enterNickname(askerNick);
      await askerConnect.registerWithPassword("pass12345");
      await asker.waitUntilConnected();
      await asker.sendMessage(`/join ${channel}`);
      await asker.expectTabVisible(channel);

      await asker.sendMessage("where should the handbook live?");

      const answererConnect = new ConnectPage(pageAnswerer);
      const answerer = new ChatPage(pageAnswerer);
      await answererConnect.open();
      await answererConnect.enterNickname(answererNick);
      await answererConnect.registerWithPassword("pass12345");
      await answerer.waitUntilConnected();
      await answerer.sendMessage(`/join ${channel}`);
      await answerer.expectTabVisible(channel);

      // Nobody has answered yet, so nothing counts anything.
      await expect(
        pageAsker.locator('[data-testid^="thread-count-"]'),
      ).toHaveCount(0);

      // Three replies, each written the way anybody writes one: from the
      // message's own menu, in the room.
      for (const text of ["on the wiki", "or in the topic", "wiki, then"]) {
        await answerer.openMessageContextMenu(
          "where should the handbook live?",
        );
        await pageAnswerer.click(
          '[data-testid="context-menu-item-reply_to_message"]',
        );
        await answerer.sendMessage(text);
      }

      // The asker's own line now says how many times it was answered, without
      // a reload — and every reply is still in the conversation.
      const counter = pageAsker.locator('[data-testid^="thread-count-"]');
      await expect(counter).toHaveCount(1);
      await expect(counter).toContainText("3");
      await expect(
        pageAsker.locator('[data-testid="chat-message-list"]'),
      ).toContainText("or in the topic");

      await shot(pageAsker, "thread-count-on-root");

      // Opening it reads the whole exchange together, in order.
      await counter.click();
      const threadWindow = pageAsker.locator('[data-testid="thread-window"]');
      await expect(threadWindow).toBeVisible();
      await expect(threadWindow.getByTestId("thread-root")).toContainText(
        "where should the handbook live?",
      );

      const lines = threadWindow.getByTestId("thread-lines");
      await expect(lines.locator('[data-testid^="thread-reply-"]')).toHaveCount(
        3,
      );
      await expect(lines).toContainText("on the wiki");
      await expect(lines).toContainText("wiki, then");

      await shot(pageAsker, "thread-window-open");

      // Replying from the window aims the room's own composer at the root, and
      // what is sent lands in both places at once.
      await threadWindow.getByTestId("thread-reply").click();
      await expect(pageAsker.getByTestId("reply-bar")).toBeVisible();
      await asker.sendMessage("wiki it is");

      await expect(lines.locator('[data-testid^="thread-reply-"]')).toHaveCount(
        4,
      );
      await expect(
        pageAsker.locator('[data-testid="chat-message-list"]'),
      ).toContainText("wiki it is");
      await expect(counter).toContainText("4");

      await shot(pageAsker, "thread-window-after-reply");
    } finally {
      await ctxAsker.close();
      await ctxAnswerer.close();
    }
  });
});
