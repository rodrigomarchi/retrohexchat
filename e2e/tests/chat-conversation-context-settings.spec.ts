import { BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'ctxsettings'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'ctxsettings') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname(prefix));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

test.describe('Conversation context channel settings', () => {
  test('Channel Settings opens Channel Central for the targeted inactive channel (V8)', async ({
    browser,
  }) => {
    const ctx: BrowserContext = await browser.newContext();
    const page = await ctx.newPage();
    const chat = await signedInUser(page, 'v8');
    const activeChannel = uniqueChannel('active');
    const targetChannel = uniqueChannel('target');

    try {
      await chat.sendMessage(`/join ${activeChannel}`);
      await chat.expectTabVisible(activeChannel);
      await chat.sendMessage(`/join ${targetChannel}`);
      await chat.expectTabVisible(targetChannel);

      await chat.switchToTab(activeChannel);
      await chat.expectTabSelected(activeChannel);

      await chat.openConversationContextMenu(targetChannel);
      await chat.conversationsSettingsMenuItem.click();

      await expect(chat.conversationsContextMenu).toBeHidden();
      await expect(chat.channelCentralDialog).toBeVisible();
      await expect(chat.channelCentralDialog).toContainText(
        `Channel Central: ${targetChannel}`,
      );
      await expect(chat.channelCentralDialog).not.toContainText(
        `Channel Central: ${activeChannel}`,
      );
      await chat.expectTabSelected(activeChannel);
    } finally {
      await ctx.close();
    }
  });
});
