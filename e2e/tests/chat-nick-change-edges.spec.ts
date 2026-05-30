import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'nickedge'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'nickedge') {
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
  prefix = 'nickedge',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Nick change edge cases', () => {
  test('nick collision shows an error and preserves both sessions and channel membership (W2)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('nickcol');
    const alice = await newSignedInUser(browser, 'w2a');
    const bob = await newSignedInUser(browser, 'w2b');
    const aliceAfterText = `nick-collision-alice-${Date.now()}`;
    const bobAfterText = `nick-collision-bob-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await alice.chat.expectNickInList(bob.nick);
      await bob.chat.expectNickInList(alice.nick);

      await alice.chat.sendMessage(`/nick ${bob.nick}`);
      await alice.chat.expectMessageVisible(
        `Nickname ${bob.nick} is already in use`,
      );
      await expect(alice.chat.nickChangeConfirmButton).toBeHidden();

      await alice.chat.expectTabVisible(channel);
      await alice.chat.expectTabSelected(channel);
      await alice.chat.expectNickInList(alice.nick);
      await alice.chat.expectNickInList(bob.nick);

      await expect(bob.chat.page).toHaveURL(/\/chat(\?.*)?$/);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.expectNickInList(bob.nick);
      await bob.chat.expectNickInList(alice.nick);

      await alice.chat.sendMessage(aliceAfterText);
      await bob.chat.expectMessageVisible(aliceAfterText);
      await expect(
        bob.chat.messageNickByText(aliceAfterText, alice.nick),
      ).toBeVisible();

      await bob.chat.sendMessage(bobAfterText);
      await alice.chat.expectMessageVisible(bobAfterText);
      await expect(
        alice.chat.messageNickByText(bobAfterText, bob.nick),
      ).toBeVisible();
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
