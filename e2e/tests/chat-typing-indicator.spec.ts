import { Browser, BrowserContext, expect, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'type') {
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
  prefix = 'type',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function openMutualPm(alice: TestUser, bob: TestUser) {
  await alice.chat.sendMessage(`/query ${bob.nick}`);
  await alice.chat.expectTabSelected(bob.nick);

  await bob.chat.sendMessage(`/query ${alice.nick}`);
  await bob.chat.expectTabSelected(alice.nick);
}

test.describe('PM typing indicator', () => {
  test('recipient sees typing indicator and it clears after send and timeout (P12)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'typa');
    const bob = await newSignedInUser(browser, 'typb');

    try {
      await openMutualPm(alice, bob);

      const sentMessage = `typing-send-${Date.now()}`;
      await alice.chat.chatInput.fill(sentMessage);
      await expect(bob.chat.typingIndicator).toHaveText(
        `${alice.nick} is typing...`,
      );

      await alice.chat.chatInput.press('Enter');
      await bob.chat.expectMessageVisible(sentMessage);
      await expect(bob.chat.typingIndicator).toHaveCount(0);

      await alice.chat.chatInput.fill(`typing-timeout-${Date.now()}`);
      await expect(bob.chat.typingIndicator).toHaveText(
        `${alice.nick} is typing...`,
      );
      await expect(bob.chat.typingIndicator).toHaveCount(0, {
        timeout: 6_000,
      });
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
