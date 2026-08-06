/**
 * @section P - Persistence, Reconnect, History, No-Focus-Steal
 * @flow P13 [done] Newest channel messages stay visible until the reader intentionally scrolls up
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  type TestUser,
  uniqueChannel,
} from "../helpers/chatUsers";
import { ChatPage } from "../pages/ChatPage";

async function sendScrollableFiller(chat: ChatPage, messages: string[]) {
  for (const message of messages) {
    await chat.sendMessage(message);
    await chat.expectMessageVisible(message, 15_000);
    await chat.page.waitForTimeout(250);
  }
}

async function messageViewportMetrics(chat: ChatPage) {
  return chat.messageList.evaluate((el) => ({
    scrollTop: Math.round(el.scrollTop),
    scrollHeight: Math.round(el.scrollHeight),
    clientHeight: Math.round(el.clientHeight),
    bottomGap: Math.round(el.scrollHeight - el.scrollTop - el.clientHeight),
  }));
}

async function expectMessageInsideViewport(chat: ChatPage, text: string) {
  await expect
    .poll(() =>
      chat.messageRowByText(text).evaluate((row) => {
        const list = row.closest('[data-testid="chat-message-list"]');
        if (!list) return false;

        const rowBox = row.getBoundingClientRect();
        const listBox = list.getBoundingClientRect();

        return rowBox.top >= listBox.top && rowBox.bottom <= listBox.bottom;
      }),
    )
    .toBe(true);
}

async function expectMessageOutsideViewport(chat: ChatPage, text: string) {
  await expect
    .poll(() =>
      chat.messageRowByText(text).evaluate((row) => {
        const list = row.closest('[data-testid="chat-message-list"]');
        if (!list) return false;

        const rowBox = row.getBoundingClientRect();
        const listBox = list.getBoundingClientRect();

        return rowBox.bottom < listBox.top || rowBox.top > listBox.bottom;
      }),
    )
    .toBe(true);
}

async function expectPinnedToBottom(chat: ChatPage) {
  await expect
    .poll(async () => (await messageViewportMetrics(chat)).bottomGap)
    .toBeLessThanOrEqual(4);
}

async function expectNoNewMessagesButton(chat: ChatPage) {
  await expect(chat.page.locator(".new-messages-btn")).toHaveCount(0);
}

async function userScrollMessagesUp(chat: ChatPage) {
  const box = await chat.messageList.boundingBox();
  expect(box).not.toBeNull();

  await chat.page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
  await chat.page.mouse.wheel(0, -1_200);

  await expect
    .poll(async () => (await messageViewportMetrics(chat)).bottomGap)
    .toBeGreaterThan(50);
}

test.describe("Chat auto-scroll", () => {
  test("keeps newest channel messages visible until the reader intentionally scrolls up", async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const alice = await newSignedInUser(browser, "ascla");
    const bob = await newSignedInUser(browser, "asclb");
    const channel = uniqueChannel("ascr");
    const marker = Date.now();
    const fillerMessages = Array.from({ length: 8 }, (_, index) => {
      const suffix = String(index + 1).padStart(2, "0");
      return [
        `autoscroll-filler-${marker}-${suffix}`,
        "wrapped viewport content ".repeat(24),
      ].join(" ");
    });
    const pinnedMessage = `autoscroll-pinned-${marker}`;
    const pausedMessage = `autoscroll-paused-${marker}`;
    const resumedMessage = `autoscroll-resumed-${marker}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);

      await sendScrollableFiller(alice.chat, fillerMessages);

      await expect
        .poll(async () => {
          const metrics = await messageViewportMetrics(alice.chat);
          return metrics.scrollHeight > metrics.clientHeight + 40;
        })
        .toBe(true);
      await expectPinnedToBottom(alice.chat);
      await expectMessageInsideViewport(alice.chat, fillerMessages.at(-1)!);
      await expectNoNewMessagesButton(alice.chat);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.switchToTab(channel);
      await alice.chat.expectNickInList(bob.nick);
      await expectPinnedToBottom(alice.chat);
      await expectNoNewMessagesButton(alice.chat);

      await bob.chat.sendMessage(pinnedMessage);
      await alice.chat.expectMessageVisible(pinnedMessage, 15_000);
      await expectPinnedToBottom(alice.chat);
      await expectMessageInsideViewport(alice.chat, pinnedMessage);
      await expectNoNewMessagesButton(alice.chat);

      await userScrollMessagesUp(alice.chat);
      await bob.chat.sendMessage(pausedMessage);
      await expect(alice.chat.messageRowByText(pausedMessage)).toContainText(
        pausedMessage,
        { timeout: 15_000 },
      );
      await expect
        .poll(async () => (await messageViewportMetrics(alice.chat)).bottomGap)
        .toBeGreaterThan(50);
      await expectMessageOutsideViewport(alice.chat, pausedMessage);
      await expectNoNewMessagesButton(alice.chat);

      await alice.chat.scrollMessagesToBottom();
      await expectPinnedToBottom(alice.chat);

      await bob.chat.sendMessage(resumedMessage);
      await alice.chat.expectMessageVisible(resumedMessage, 15_000);
      await expectPinnedToBottom(alice.chat);
      await expectMessageInsideViewport(alice.chat, resumedMessage);
      await expectNoNewMessagesButton(alice.chat);
    } finally {
      await closeUsers([alice, bob] satisfies TestUser[]);
    }
  });
});
