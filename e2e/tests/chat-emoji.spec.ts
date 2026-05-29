import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'emoji',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, page, nick };
}

test.describe('Emoji picker', () => {
  test('opens, searches, inserts an emoji, and closes (O1)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'emoji');

    try {
      await user.chat.emojiPickerToggle.click();
      await expect(user.chat.emojiPicker).toBeVisible();

      await user.chat.emojiPickerSearch.fill('dog');
      await expect(user.chat.emojiButton('🐶')).toBeVisible({
        timeout: 10_000,
      });
      await expect(user.chat.emojiButton('😀')).toHaveCount(0);

      await user.chat.emojiButton('🐶').click();

      await expect(user.chat.emojiPicker).toHaveCount(0);
      await expect(user.chat.chatInput).toHaveValue('🐶');

      await user.chat.emojiPickerToggle.click();
      await expect(user.chat.emojiPicker).toBeVisible();
      await user.page.keyboard.press('Escape');
      await expect(user.chat.emojiPicker).toHaveCount(0);
    } finally {
      await user.ctx.close();
    }
  });
});
