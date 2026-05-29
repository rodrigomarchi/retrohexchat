import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

function uniqueChannel(prefix = 'arlo'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'arlo',
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

async function joinChannel(user: TestUser, channel: string) {
  await user.chat.sendMessage(`/join ${channel}`);
  await user.chat.expectTabVisible(channel);
  await user.chat.expectTabSelected(channel);
}

test.describe('Auto-respond loop prevention', () => {
  test('reciprocal autorespond notices fire once and do not loop (Y10)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'arla');
    const bob = await newSignedInUser(browser, 'arlb');
    const visitor = await newSignedInUser(browser, 'arlv');
    const channel = uniqueChannel('arloop');
    const aliceText = `alice-autorespond-${Date.now()}`;
    const bobText = `bob-autorespond-${Date.now()}`;

    try {
      await joinChannel(alice, channel);
      await joinChannel(bob, channel);

      await alice.chat.sendMessage(
        `/autorespond add on_join ${channel} /notice $nick ${aliceText}`,
      );
      await alice.chat.expectMessageVisible('Auto-respond rule added: on_join');

      await bob.chat.sendMessage(
        `/autorespond add on_join ${channel} /notice $nick ${bobText}`,
      );
      await bob.chat.expectMessageVisible('Auto-respond rule added: on_join');

      await joinChannel(visitor, channel);

      await visitor.chat.expectMessageVisible(aliceText, 15_000);
      await visitor.chat.expectMessageVisible(bobText, 15_000);
      await visitor.page.waitForTimeout(1_500);

      await expect(visitor.chat.messageList.getByText(aliceText)).toHaveCount(1);
      await expect(visitor.chat.messageList.getByText(bobText)).toHaveCount(1);
      await expect(alice.chat.tab(bob.nick)).toHaveCount(0);
      await expect(bob.chat.tab(alice.nick)).toHaveCount(0);
    } finally {
      await alice.chat.sendMessage('/autorespond remove 0').catch(() => {});
      await bob.chat.sendMessage('/autorespond remove 0').catch(() => {});
      await closeUsers([alice, bob, visitor]);
    }
  });
});
