import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
};

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, ctx, page };
}

test.describe('Admin singleplayer command', () => {
  test('/singleplayer emits a usable solo arcade link (M20)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    let popup: Page | undefined;

    try {
      await admin.chat.sendMessage('/singleplayer');
      await admin.chat.expectMessageVisible('Arcade session ready!');

      const link = admin.chat.arcadeSessionLink();
      await expect(link).toBeVisible();
      await expect(link).toHaveAttribute('href', /^\/solo\/[A-Za-z0-9_-]+$/);

      const popupPromise = admin.page.waitForEvent('popup');
      await link.click();
      popup = await popupPromise;

      await expect(popup).toHaveURL(/\/solo\/[A-Za-z0-9_-]+$/);
      await expect(popup.locator('#solo-lobby')).toBeVisible();
      await expect(popup.getByText('Retro Arcade')).toBeVisible();
    } finally {
      await popup?.close().catch(() => {});
      await admin.ctx.close();
    }
  });
});
