import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'hover'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'hover') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'hover',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function setupTwoUsersInChannels(
  browser: Browser,
  channels: [string, string],
) {
  const alice = await newSignedInUser(browser, 'hova');
  const bob = await newSignedInUser(browser, 'hovb');

  for (const channel of channels) {
    await alice.chat.sendMessage(`/join ${channel}`);
    await alice.chat.expectTabVisible(channel);
    await bob.chat.sendMessage(`/join ${channel}`);
    await bob.chat.expectTabVisible(channel);
  }

  await alice.chat.switchToTab(channels[1]);
  await bob.chat.switchToTab(channels[1]);
  await alice.chat.expectNickInList(bob.nick);

  return { alice, bob };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Hover card', () => {
  test('hovering a nick shows registered, away, idle, client, and shared channel details (O14)', async ({
    browser,
  }) => {
    const channelA = uniqueChannel('hova');
    const channelB = uniqueChannel('hovb');
    const { alice, bob } = await setupTwoUsersInChannels(browser, [
      channelA,
      channelB,
    ]);
    const away = `hover-away-${Date.now()}`;
    const text = `hover-card-message-${Date.now()}`;

    try {
      await bob.chat.sendMessage(`/away ${away}`);
      await bob.chat.expectMessageVisible(`You are now away: ${away}`);
      await bob.chat.sendMessage(text);
      await alice.chat.expectMessageVisible(text);

      await alice.chat.messageNickByText(text, bob.nick).hover();

      const card = alice.chat.hoverCard(bob.nick);
      await expect(card).toBeVisible();
      await expect(card).toContainText('Registered');
      await expect(card).toContainText('Away');
      await expect(card).toContainText(away);
      await expect(card).toContainText('For');
      await expect(card).toContainText('Idle');
      await expect(card).toContainText('Browser');
      await expect(card).toContainText(channelA);
      await expect(card).toContainText(channelB);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
