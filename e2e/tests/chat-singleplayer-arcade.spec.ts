import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';
import { SoloArcadePage, openSoloArcadeFromChat } from '../pages/SoloArcadePage';

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

async function expectArcadeWindowLoaded(page: Page) {
  await expect(page).toHaveURL(
    /^https:\/\/static\.retrohexchat\.app\/arcade\/doom_shareware\/index\.html/,
    { timeout: 20_000 },
  );
  await expect(page.locator('#canvas')).toBeAttached({ timeout: 20_000 });
  await expect
    .poll(
      () =>
        page.evaluate(() => {
          const text = document.body?.innerText?.trim() || '';
          const canvas = document.querySelector('#canvas');
          return {
            textLength: text.length,
            hasCanvas: canvas instanceof HTMLCanvasElement,
          };
        }),
      { timeout: 20_000 },
    )
    .toEqual({ textLength: expect.any(Number), hasCanvas: true });

  const textLength = await page.evaluate(
    () => document.body?.innerText?.trim().length || 0,
  );
  expect(textLength).toBeGreaterThan(0);
}

test.describe('Solo arcade lifecycle', () => {
  test('solo arcade opens an external playable frame and returns to chat after the game window closes (Z12)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    let solo: SoloArcadePage | undefined;
    let gameWindow: Page | undefined;

    try {
      await admin.chat.sendMessage('/singleplayer');
      await admin.chat.expectMessageVisible('Arcade session ready!');

      solo = await openSoloArcadeFromChat(admin.page, admin.chat.arcadeSessionLink());

      await solo.previewGame('doom_shareware');
      gameWindow = await solo.startGame('doom_shareware');

      await solo.expectPlaying('DOOM: Knee-Deep in the Dead');
      await expectArcadeWindowLoaded(gameWindow);

      await gameWindow.close();
      await solo.expectFinished();

      const soloClosed = solo.page.waitForEvent('close');
      await solo.close();
      await soloClosed;

      await expect(admin.page).toHaveURL(/\/chat$/);
      await expect(admin.chat.chatInput).toBeVisible();
    } finally {
      await gameWindow?.close().catch(() => {});
      await solo?.page.close().catch(() => {});
      await admin.ctx.close();
    }
  });
});
