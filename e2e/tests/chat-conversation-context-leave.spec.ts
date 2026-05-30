import { BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
};

function uniqueChannel(prefix = 'leavectx'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'leavectx') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname(prefix));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

test.describe('Conversation context leave actions', () => {
  test('Leave removes only the targeted inactive or active channel (V7)', async ({
    browser,
  }) => {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    const user: TestUser = { chat: await signedInUser(page, 'v7'), ctx };
    const activeChannel = uniqueChannel('active');
    const inactiveChannel = uniqueChannel('inactive');

    try {
      await user.chat.sendMessage(`/join ${activeChannel}`);
      await user.chat.expectTabVisible(activeChannel);
      await user.chat.sendMessage(`/join ${inactiveChannel}`);
      await user.chat.expectTabVisible(inactiveChannel);

      await user.chat.switchToTab(activeChannel);
      await user.chat.expectTabSelected(activeChannel);

      await user.chat.openConversationContextMenu(inactiveChannel);
      await user.chat.conversationsLeaveMenuItem.click();
      await expect(user.chat.conversationsContextMenu).toBeHidden();
      await user.chat.expectTabHidden(inactiveChannel);
      await expect(user.chat.channelConversationItem(inactiveChannel)).toHaveCount(0);
      await user.chat.expectTabVisible(activeChannel);
      await expect(user.chat.channelConversationItem(activeChannel)).toBeVisible();
      await user.chat.expectTabSelected(activeChannel);

      await user.chat.openConversationContextMenu(activeChannel);
      await user.chat.conversationsLeaveMenuItem.click();
      await expect(user.chat.conversationsContextMenu).toBeHidden();
      await user.chat.expectTabHidden(activeChannel);
      await expect(user.chat.channelConversationItem(activeChannel)).toHaveCount(0);
      await user.chat.expectTabSelected('#lobby');
    } finally {
      await user.ctx.close();
    }
  });
});
