import { Browser, BrowserContext, Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
};

function uniqueChannel(prefix = 'render'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(browser: Browser): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await page.setViewportSize({ width: 1280, height: 720 });
  await connect.open();
  await connect.enterNickname(uniqueNickname('render'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, page };
}

async function expectNoDocumentHorizontalOverflow(page: Page) {
  const metrics = await page.evaluate(() => {
    const root = document.documentElement;
    const body = document.body;

    return {
      rootClientWidth: root.clientWidth,
      rootScrollWidth: root.scrollWidth,
      bodyClientWidth: body.clientWidth,
      bodyScrollWidth: body.scrollWidth,
    };
  });

  expect(metrics.rootScrollWidth).toBeLessThanOrEqual(metrics.rootClientWidth + 2);
  expect(metrics.bodyScrollWidth).toBeLessThanOrEqual(metrics.bodyClientWidth + 2);
}

async function expectNoElementHorizontalOverflow(locator: Locator) {
  const metrics = await locator.evaluate((el) => {
    const htmlEl = el as HTMLElement;

    return {
      clientWidth: htmlEl.clientWidth,
      scrollWidth: htmlEl.scrollWidth,
    };
  });

  expect(metrics.scrollWidth).toBeLessThanOrEqual(metrics.clientWidth + 2);
}

test.describe('Message rendering robustness', () => {
  test('long unbroken words and very long URLs stay inside the desktop chat layout (R4)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser);
    const channel = uniqueChannel();
    const wordMarker = `longword-${Date.now()}`;
    const urlMarker = `longurl-${Date.now()}`;
    const longWord = `word${'w'.repeat(420)}`;
    const longUrl = `https://example.com/${'very-long-path'.repeat(55)}`;

    try {
      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);
      await user.chat.expectTabSelected(channel);

      await user.chat.sendMessage(`${wordMarker} ${longWord}`);
      const wordRow = user.chat.messageRowByText(wordMarker);
      await expect(wordRow).toBeVisible();

      await user.chat.sendMessage(`${urlMarker} ${longUrl}`);
      const urlRow = user.chat.messageRowByText(urlMarker);
      await expect(urlRow).toBeVisible();
      await expect(urlRow.locator('a').first()).toHaveAttribute('title', longUrl);

      await expectNoDocumentHorizontalOverflow(user.page);
      await expectNoElementHorizontalOverflow(user.chat.messageList);
      await expectNoElementHorizontalOverflow(wordRow);
      await expectNoElementHorizontalOverflow(urlRow);
    } finally {
      await user.ctx.close();
    }
  });
});
