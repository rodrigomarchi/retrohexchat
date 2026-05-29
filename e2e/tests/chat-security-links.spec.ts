import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

function uniqueChannel(prefix = 'seclink'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'secl',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, page, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Security link handling', () => {
  test('unsafe URL schemes are not rendered as clickable links (R3)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'secl');
    const channel = uniqueChannel();
    const marker = `unsafe-link-${Date.now()}`;
    const javascriptUrl = `javascript:window.__unsafeLink='${marker}'`;
    const dataUrl = `data:text/html,<script>window.__unsafeLink='${marker}'</script>`;

    try {
      await user.page.evaluate(() => {
        (window as Window & { __unsafeLink?: string }).__unsafeLink = 'clean';
      });

      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);
      await user.chat.switchToTab(channel);

      await user.chat.sendMessage(`${marker} ${javascriptUrl} ${dataUrl}`);

      const row = user.chat.messageRowByText(marker);
      await expect(row).toBeVisible();
      await expect(row.locator('a[href^="javascript:"]')).toHaveCount(0);
      await expect(row.locator('a[href^="data:"]')).toHaveCount(0);
      await expect(row.locator('a')).toHaveCount(0);
      await expect(
        user.chat.urlCatcherRows.filter({ hasText: javascriptUrl }),
      ).toHaveCount(0);
      await expect
        .poll(() =>
          user.page.evaluate(
            () => (window as Window & { __unsafeLink?: string }).__unsafeLink,
          ),
        )
        .toBe('clean');
    } finally {
      await closeUsers([user]);
    }
  });
});
