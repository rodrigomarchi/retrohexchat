import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'awayedge'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'awayedge') {
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
  prefix = 'awayedge',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Away edge cases', () => {
  test('away auto-reply resets after away is cleared and set again (W7)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'w7a');
    const bob = await newSignedInUser(browser, 'w7b');
    const away1 = `away-first-${Date.now()}`;
    const away2 = `away-second-${Date.now()}`;

    try {
      await bob.chat.sendMessage(`/away ${away1}`);
      await bob.chat.expectMessageVisible(`You are now away: ${away1}`);

      await alice.chat.sendMessage(`/msg ${bob.nick} away-ping-1`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageVisible(`${bob.nick} is away: ${away1}`);

      await alice.chat.sendMessage('away-ping-2');
      await expect(
        alice.chat.messageList.getByText(`${bob.nick} is away: ${away1}`),
      ).toHaveCount(1, { timeout: 1_000 });

      await bob.chat.sendMessage('/away');
      await bob.chat.expectMessageVisible('You are no longer away');

      await bob.chat.sendMessage(`/away ${away2}`);
      await bob.chat.expectMessageVisible(`You are now away: ${away2}`);

      await alice.chat.sendMessage('away-ping-3');
      await alice.chat.expectMessageVisible(`${bob.nick} is away: ${away2}`);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('away state updates nicklist and hover card for already-open channels (W8)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'w8a');
    const bob = await newSignedInUser(browser, 'w8b');
    const channel = uniqueChannel('w8away');
    const away = `away-nicklist-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);

      await alice.chat.switchToTab(channel);
      await bob.chat.switchToTab(channel);
      await alice.chat.expectNickInList(bob.nick);
      await alice.chat.expectNickStatus(bob.nick, 'online');

      await bob.chat.sendMessage(`/away ${away}`);
      await bob.chat.expectMessageVisible(`You are now away: ${away}`);
      await alice.chat.expectNickStatus(bob.nick, 'away');

      await alice.chat.openNickHoverCard(bob.nick);
      const card = alice.chat.hoverCard(bob.nick);
      await expect(card).toContainText('Away');
      await expect(card).toContainText(away);

      await bob.chat.sendMessage('/away');
      await bob.chat.expectMessageVisible('You are no longer away');
      await alice.chat.expectNickStatus(bob.nick, 'online');
      await expect(card).not.toContainText(away);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
