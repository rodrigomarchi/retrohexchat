/**
 * @section S - Message Lifecycle Additions
 * @flow S15 [done] An operator pins a line from its right-click menu; every member gets the Pinned button and the window lists it; Unpin there removes it
 * @flow S16 [done] `/pin <id>` and `/unpin <id>` do the same by number; a regular member is refused and has no Pin menu item
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  TestUser,
  uniqueChannel,
} from "../helpers/chatUsers";
import { ChatPage } from "../pages/ChatPage";

async function ownerAndMemberIn(
  browser: import("@playwright/test").Browser,
  channel: string,
): Promise<[TestUser, TestUser]> {
  const owner = await newSignedInUser(browser, "pinown");
  const member = await newSignedInUser(browser, "pinmem");

  for (const user of [owner, member]) {
    await user.chat.sendMessage(`/join ${channel}`);
    await user.chat.expectTabVisible(channel);
  }
  await owner.chat.expectNickInList(member.nick);

  return [owner, member];
}

/** The number a message is stored under, read off its row on screen. */
async function messageId(chat: ChatPage, text: string): Promise<string> {
  const domId = await chat
    .messageRowByText(text)
    .getAttribute("data-message-id");
  const id = domId?.match(/(\d+)$/)?.[1];
  expect(id, `no stored id on the row of "${text}" (${domId})`).toBeTruthy();
  return id!;
}

test.describe("Pinned messages", () => {
  test("an operator pins a line from its menu and unpins it from the window (S15)", async ({
    browser,
  }) => {
    const channel = uniqueChannel("pin");
    const [owner, member] = await ownerAndMemberIn(browser, channel);
    const rules = `channel rules ${Date.now()}`;

    try {
      await member.chat.sendMessage(rules);
      await owner.chat.expectMessageVisible(rules);

      // Nothing is pinned yet, so there is no button to open an empty window.
      await expect(
        owner.page.getByTestId("conversation-toolbar-pinned"),
      ).toBeHidden();

      await owner.chat.openMessageContextMenu(rules);
      await owner.page
        .getByTestId("context-menu-item-ctx_chat_pin_message")
        .click();

      for (const user of [owner, member]) {
        await expect(
          user.page.getByTestId("conversation-toolbar-pinned"),
        ).toContainText("Pinned (1)");
      }

      const id = await messageId(owner.chat, rules);
      await member.chat.openPinnedFromToolbar();
      const row = member.page.getByTestId(`pinned-row-${id}`);
      await expect(row).toContainText(rules);
      await expect(row).toContainText(`pinned by ${owner.nick}`);
      // Only an operator can take it down again.
      await expect(member.page.getByTestId(`pinned-unpin-${id}`)).toBeHidden();

      await owner.chat.openPinnedFromToolbar();
      await owner.page.getByTestId(`pinned-unpin-${id}`).click();

      for (const user of [owner, member]) {
        await expect(
          user.page.getByTestId("conversation-toolbar-pinned"),
        ).toBeHidden();
      }
    } finally {
      await closeUsers([owner, member]);
    }
  });

  test("/pin and /unpin work by message number and only for operators (S16)", async ({
    browser,
  }) => {
    const channel = uniqueChannel("pinid");
    const [owner, member] = await ownerAndMemberIn(browser, channel);
    const line = `pin by number ${Date.now()}`;

    try {
      await owner.chat.sendMessage(line);
      await member.chat.expectMessageVisible(line);
      const id = await messageId(owner.chat, line);

      await owner.chat.sendMessage("/pin");
      await owner.chat.expectMessageVisible(
        "Which message? Use /pin <id>, or pin it from its right-click menu.",
      );

      // A regular member is told why, and their menu never offers the item.
      await member.chat.sendMessage(`/pin ${id}`);
      await member.chat.expectMessageVisible(
        "You must be a channel operator to pin messages",
      );
      await member.chat.openMessageContextMenu(line);
      await expect(
        member.page.getByTestId("context-menu-item-ctx_chat_pin_message"),
      ).toHaveCount(0);
      await member.page.keyboard.press("Escape");

      await owner.chat.sendMessage(`/pin ${id}`);
      await expect(
        member.page.getByTestId("conversation-toolbar-pinned"),
      ).toContainText("Pinned (1)");

      await owner.chat.sendMessage(`/unpin ${id}`);
      await expect(
        member.page.getByTestId("conversation-toolbar-pinned"),
      ).toBeHidden();
    } finally {
      await closeUsers([owner, member]);
    }
  });
});
