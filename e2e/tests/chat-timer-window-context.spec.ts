import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'timerctx'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

function uniqueTimer(prefix = 'tmctx'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix: string,
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

  return { chat, ctx, nick };
}

test.describe('Timer window context', () => {
  test('timer output targets the creation window while another tab is active (Y5)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'y5a');
    const bob = await newSignedInUser(browser, 'y5b');
    const origin = uniqueChannel('y5src');
    const active = uniqueChannel('y5dst');
    const timerName = uniqueTimer('y5');
    const marker = `timer-window-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${origin}`);
      await alice.chat.expectTabVisible(origin);
      await alice.chat.sendMessage(`/join ${active}`);
      await alice.chat.expectTabVisible(active);

      await bob.chat.sendMessage(`/join ${origin}`);
      await bob.chat.expectTabVisible(origin);

      await alice.chat.switchToTab(origin);
      await alice.chat.sendMessage(`/timer ${timerName} 1 /me ${marker}`);
      await alice.chat.expectMessageVisible(`* Timer '${timerName}' set`);

      await alice.chat.switchToTab(active);

      await bob.chat.expectMessageVisible(marker, 5_000);
      await alice.chat.expectTabSelected(active);
      await alice.chat.expectMessageHidden(marker);

      await alice.chat.switchToTab(origin);
      await alice.chat.expectMessageVisible(marker);
    } finally {
      await alice.ctx.close();
      await bob.ctx.close();
    }
  });

  test('timer command that opens a PM tab does not switch the active tab (Y6)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'y6a');
    const bob = await newSignedInUser(browser, 'y6b');
    const origin = uniqueChannel('y6src');
    const active = uniqueChannel('y6dst');
    const timerName = uniqueTimer('y6');

    try {
      await alice.chat.sendMessage(`/join ${origin}`);
      await alice.chat.expectTabVisible(origin);
      await alice.chat.sendMessage(`/join ${active}`);
      await alice.chat.expectTabVisible(active);

      await alice.chat.switchToTab(origin);
      await alice.chat.sendMessage(`/timer ${timerName} 1 /query ${bob.nick}`);
      await alice.chat.expectMessageVisible(`* Timer '${timerName}' set`);

      await alice.chat.switchToTab(active);

      await expect(alice.chat.tab(bob.nick)).toBeVisible({ timeout: 5_000 });
      await alice.chat.expectTabSelected(active);
    } finally {
      await alice.ctx.close();
      await bob.ctx.close();
    }
  });
});
