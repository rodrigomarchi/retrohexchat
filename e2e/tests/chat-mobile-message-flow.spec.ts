/**
 * @section MB - Mobile & Touch
 * @flow MB5 [done] Emoji opens from the mobile composer and inserts into a message
 * @flow MB6 [done] Long press drives reply and edit without a hardware keyboard
 * @flow MB7 [done] Message deletion confirms and cancels from the long-press menu
 * @flow MB8 [done] PM reply, edit, and delete work from touch message actions
 * @flow MB9 [done] Nicklist and conversation actions open by long press
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import {
  Browser,
  BrowserContext,
  devices,
  expect,
  Locator,
  Page,
  test,
} from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { e2eBaseURL } from "../helpers/env";

const PIXEL_5 = devices["Pixel 5"];
const PHONE = {
  viewport: PIXEL_5.viewport,
  userAgent: PIXEL_5.userAgent,
  deviceScaleFactor: PIXEL_5.deviceScaleFactor,
  isMobile: PIXEL_5.isMobile,
  hasTouch: PIXEL_5.hasTouch,
};
const LONG_PRESS_MS = 650;

test.use(PHONE);

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = "mflow") {
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
  prefix = "mflow",
): Promise<TestUser> {
  const ctx = await browser.newContext({ ...PHONE, baseURL: e2eBaseURL() });
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

function uniqueChannel(prefix = "mflow"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function longPress(page: Page, target: Locator) {
  await expect(target).toBeVisible();

  const box = await target.boundingBox();
  expect(box).not.toBeNull();

  const x = box!.x + Math.min(box!.width / 2, box!.width - 8);
  const y = box!.y + Math.min(box!.height / 2, box!.height - 8);
  const eventInit = {
    bubbles: true,
    cancelable: true,
    pointerId: 1,
    pointerType: "touch",
    isPrimary: true,
    clientX: x,
    clientY: y,
  };

  await target.dispatchEvent("pointerdown", {
    ...eventInit,
    button: 0,
    buttons: 1,
  });
  await page.waitForTimeout(LONG_PRESS_MS);
  await target.dispatchEvent("pointerup", {
    ...eventInit,
    button: 0,
    buttons: 0,
  });
}

async function openMessageActionsByLongPress(chat: ChatPage, text: string) {
  await longPress(chat.page, chat.messageRowByText(text));
  await expect(chat.chatContextMenu).toBeVisible();
}

async function openNicklistActionsByLongPress(chat: ChatPage, nick: string) {
  await longPress(chat.page, chat.nicklistItem(nick));
  await expect(chat.nicklistContextMenu).toBeVisible();
}

async function openConversationActionsByLongPress(
  chat: ChatPage,
  channel: string,
) {
  await longPress(chat.page, chat.channelConversationItem(channel));
  await expect(chat.conversationsContextMenu).toBeVisible();
}

async function expectTouchSized(locator: Locator) {
  const box = await locator.boundingBox();
  expect(box).not.toBeNull();
  expect(box!.height).toBeGreaterThanOrEqual(36);
  expect(box!.width).toBeGreaterThanOrEqual(36);
}

test.describe("mobile chat message flow", () => {
  test("opens emoji from the mobile composer and inserts into a message", async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, "memoji");

    await expect(chat.formattingToolbarToggle).toBeVisible();
    await expectTouchSized(chat.formattingToolbarToggle);

    await chat.openEmojiPicker();
    await expect(chat.emojiPicker).toBeVisible();

    const pickerBox = await chat.emojiPicker.boundingBox();
    expect(pickerBox).not.toBeNull();
    expect(pickerBox!.height).toBeLessThanOrEqual(360);

    await chat.emojiPickerSearch.fill("dog");
    await expect(chat.emojiButton("🐶")).toBeVisible({ timeout: 10_000 });

    await chat.emojiButton("🐶").click();
    await expect(chat.emojiPicker).toHaveCount(0);
    await expect(chat.chatInput).toHaveValue("🐶");

    await chat.chatSendButton.click();
    await chat.expectMessageVisible("🐶");
  });

  test("uses long press for reply and edit without a hardware keyboard", async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page, "mmsg");
    const marker = Date.now();
    const original = `mobile-original-${marker}`;
    const reply = `mobile-reply-${marker}`;
    const updated = `mobile-updated-${marker}`;

    await chat.sendMessage(original);
    await chat.expectMessageVisible(original);

    await openMessageActionsByLongPress(chat, original);
    await expect(chat.contextReplyMenuItem).toBeVisible();
    await expect(chat.contextEditMenuItem).toBeVisible();

    await chat.contextReplyMenuItem.click();
    await expect(chat.chatContextMenu).toBeHidden();
    await expect(chat.replyBar).toBeVisible();
    await expect(chat.replyBar).toContainText(nick);
    await expect(chat.replyBar).toContainText(original);
    await expectTouchSized(chat.replyBarDismissButton);

    await chat.sendMessage(reply);
    await chat.expectMessageVisible(reply);
    await expect(chat.replyBar).toBeHidden();

    const replyBlock = chat.messageRowByText(reply).getByTestId("reply-block");
    await expect(replyBlock).toBeVisible();
    await expect(replyBlock).toContainText(original);

    await openMessageActionsByLongPress(chat, original);
    await chat.contextEditMenuItem.click();
    await expect(chat.chatContextMenu).toBeHidden();
    await expect(chat.chatInput).toHaveValue(original);

    await chat.chatInput.fill(updated);
    await chat.chatSendButton.click();

    const updatedRow = chat.messageRowByText(updated);
    await expect(updatedRow).toBeVisible();
    await expect(updatedRow.getByTestId("edited-tag")).toBeVisible();
    await expect(chat.chatInput).toHaveValue("");
  });

  test("confirms and cancels message deletion from the long-press menu", async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, "mdel");
    const channel = uniqueChannel("mdel");
    const marker = Date.now();
    const original = `mobile-delete-${marker}`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);
    await chat.switchToTab(channel);

    await chat.sendMessage(original);
    await chat.expectMessageVisible(original);

    await openMessageActionsByLongPress(chat, original);
    await expect(chat.contextDeleteMenuItem).toBeVisible();
    await chat.contextDeleteMenuItem.click();
    await expect(chat.deleteConfirmButton).toBeVisible();
    await expectTouchSized(chat.deleteConfirmButton);
    await expectTouchSized(chat.deleteCancelButton);

    await chat.deleteCancelButton.click();
    await expect(chat.deleteConfirmButton).toBeHidden();
    await chat.expectMessageVisible(original);

    await openMessageActionsByLongPress(chat, original);
    await chat.contextDeleteMenuItem.click();
    await expect(chat.deleteConfirmButton).toBeVisible();
    await chat.deleteConfirmButton.click();

    await expect(chat.messageList.getByTestId("deleted-message")).toBeVisible();
    await expect(chat.messageList.getByText(original)).toHaveCount(0);
  });

  test("supports PM reply, edit, and delete from touch message actions", async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, "mpma");
    const bob = await newSignedInUser(browser, "mpmb");
    const marker = Date.now();
    const parent = `mobile-pm-parent-${marker}`;
    const reply = `mobile-pm-reply-${marker}`;
    const updated = `mobile-pm-updated-${marker}`;

    try {
      const channel = uniqueChannel("mpm");

      await alice.chat.sendMessage(`/join ${channel}`);
      await bob.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await bob.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);

      await alice.chat.page
        .getByTestId("conversation-toolbar-nicklist")
        .click();
      await expect(alice.chat.nicklist).toBeVisible();
      await alice.chat.expectNickInList(bob.nick);
      await openNicklistActionsByLongPress(alice.chat, bob.nick);
      await alice.chat.nicklistContextQueryMenuItem.click();
      await expect(alice.chat.nicklistContextMenu).toBeHidden();
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.switchToTab(bob.nick);

      await alice.chat.sendMessage(parent);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await bob.chat.expectMessageVisible(parent);

      await openMessageActionsByLongPress(bob.chat, parent);
      await bob.chat.contextReplyMenuItem.click();
      await expect(bob.chat.replyBar).toBeVisible();
      await expect(bob.chat.replyBar).toContainText(alice.nick);
      await expect(bob.chat.replyBar).toContainText(parent);

      await bob.chat.sendMessage(reply);
      await bob.chat.expectMessageVisible(reply);
      await alice.chat.expectMessageVisible(reply);
      await expect(
        bob.chat.messageRowByText(reply).getByTestId("reply-block"),
      ).toContainText(parent);

      await openMessageActionsByLongPress(bob.chat, reply);
      await bob.chat.contextEditMenuItem.click();
      await expect(bob.chat.chatInput).toHaveValue(reply);
      await bob.chat.chatInput.fill(updated);
      await bob.chat.chatSendButton.click();

      await bob.chat.expectMessageVisible(updated);
      await alice.chat.expectMessageVisible(updated);
      await expect(
        bob.chat.messageRowByText(updated).getByTestId("edited-tag"),
      ).toBeVisible();
      await expect(
        alice.chat.messageRowByText(updated).getByTestId("edited-tag"),
      ).toBeVisible();

      await openMessageActionsByLongPress(bob.chat, updated);
      await bob.chat.contextDeleteMenuItem.click();
      await expect(bob.chat.deleteConfirmButton).toBeVisible();
      await bob.chat.deleteConfirmButton.click();

      await expect(
        bob.chat.messageList.getByTestId("deleted-message"),
      ).toBeVisible();
      await expect(
        alice.chat.messageList.getByTestId("deleted-message"),
      ).toBeVisible();
      await expect(bob.chat.messageList.getByText(updated)).toHaveCount(0);
      await expect(alice.chat.messageList.getByText(updated)).toHaveCount(0);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test("opens nicklist and conversation actions by long press", async ({
    browser,
  }) => {
    const channelA = uniqueChannel("mctxa");
    const channelB = uniqueChannel("mctxb");
    const alice = await newSignedInUser(browser, "mctxa");
    const bob = await newSignedInUser(browser, "mctxb");

    try {
      await alice.chat.sendMessage(`/join ${channelA}`);
      await bob.chat.sendMessage(`/join ${channelA}`);
      await alice.chat.expectTabVisible(channelA);
      await bob.chat.expectTabVisible(channelA);

      await alice.chat.sendMessage(`/join ${channelB}`);
      await alice.chat.expectTabVisible(channelB);
      await alice.chat.switchToTab(channelA);

      await alice.chat.page
        .getByTestId("conversation-toolbar-nicklist")
        .click();
      await expect(alice.chat.nicklist).toBeVisible();
      await alice.chat.expectNickInList(bob.nick);
      await openNicklistActionsByLongPress(alice.chat, bob.nick);
      await expect(alice.chat.nicklistContextQueryMenuItem).toBeVisible();
      await expect(alice.chat.nicklistContextWhoisMenuItem).toBeVisible();

      await alice.chat.page.keyboard.press("Escape");
      await expect(alice.chat.nicklistContextMenu).toBeHidden();

      await alice.chat.page
        .getByTestId("conversation-toolbar-conversations")
        .click();
      await expect(alice.chat.channelConversationItem(channelB)).toBeVisible();
      await openConversationActionsByLongPress(alice.chat, channelB);
      await expect(alice.chat.conversationsMuteMenuItem).toContainText(
        "Mute Channel",
      );

      await alice.chat.conversationsMuteMenuItem.click();
      await expect(alice.chat.conversationsContextMenu).toBeHidden();
      await alice.chat.expectChannelConversationMuted(channelB, true);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
