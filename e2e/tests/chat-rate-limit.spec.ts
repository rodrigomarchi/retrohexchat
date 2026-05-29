import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'ratelimit'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(browser: Browser, prefix: string): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectNoPendingMessages(chat: ChatPage) {
  await expect(chat.messageList.locator('[data-msg-status="pending"]')).toHaveCount(0);
}

async function expectInputIdle(chat: ChatPage) {
  await expect(chat.chatInput).toBeEnabled();
  await expect(chat.chatInput).toHaveValue('');
  await expect(chat.chatSendButton).toBeDisabled();
}

test.describe('Rate-limit and send-error input state', () => {
  test('P2P command rate-limit errors leave no pending messages and keep input usable (R9)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'rcla');
    const bob = await newSignedInUser(browser, 'rclb');
    const afterLimit = `after-p2p-rate-limit-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );

      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await alice.chat.expectMessageVisible(
        `P2P invite sent to ${bob.nick}. Waiting for response...`,
      );

      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await alice.chat.expectMessageVisible('Too many sessions created. Try again in');

      await expectNoPendingMessages(alice.chat);
      await expectInputIdle(alice.chat);

      await alice.chat.sendMessage(afterLimit);
      await alice.chat.expectMessageVisible(afterLimit);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('failed channel sends clear pending state and leave input ready after flood-style errors (R9)', async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const alice = await newSignedInUser(browser, 'rfla');
    const bob = await newSignedInUser(browser, 'rflb');
    const blocked = `moderated-blocked-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await bob.chat.switchToTab(channel);

      await alice.chat.sendMessage('/mode +m');
      await alice.chat.expectMessageVisible(`${alice.nick} sets mode +m`);

      await bob.chat.sendMessage(blocked);
      const failedRow = bob.chat.messageRowByText(blocked);
      await expect(failedRow).toHaveAttribute('data-msg-status', 'failed');
      await expect(failedRow.getByTestId('retry-message')).toBeVisible();
      await alice.chat.expectMessageHidden(blocked);

      await expectNoPendingMessages(bob.chat);
      await expectInputIdle(bob.chat);

      await bob.chat.chatInput.fill('draft after failed send');
      await expect(bob.chat.chatSendButton).toBeEnabled();
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
