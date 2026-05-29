import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'retry'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'retry') {
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
  prefix = 'retry',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'rtya');
  const bob = await newSignedInUser(browser, 'rtyb');

  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);

  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);

  await alice.chat.switchToTab(channel);
  await alice.chat.expectNickInList(bob.nick);

  return { alice, bob };
}

test.describe('Failed message retry lifecycle', () => {
  test('failed pending message retry succeeds after blocking mode is removed (S10)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('retrymode');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const text = `retry-after-mode-remove-${Date.now()}`;

    try {
      await alice.chat.sendMessage('/mode +m');
      await alice.chat.expectMessageVisible(`${alice.nick} sets mode +m`);

      await bob.chat.sendMessage(text);
      const failedRow = bob.chat.messageRowByText(text);
      await expect(failedRow).toHaveAttribute('data-msg-status', 'failed');
      await expect(failedRow.getByTestId('retry-message')).toBeVisible();
      await alice.chat.expectMessageHidden(text);

      await alice.chat.sendMessage('/mode -m');
      await alice.chat.expectMessageVisible(`${alice.nick} sets mode -m`);

      await failedRow.getByTestId('retry-message').click();

      await alice.chat.expectMessageVisible(text);
      await bob.chat.expectMessageVisible(text);
      await expect(bob.chat.messageList.getByTestId('retry-message')).toHaveCount(0);
      await expect(bob.chat.messageRows.filter({ hasText: text })).toHaveCount(1);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('failed pending message can be deleted without leaving orphan UI (S11)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('retrydel');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const text = `delete-failed-pending-${Date.now()}`;

    try {
      await alice.chat.sendMessage('/mode +m');
      await alice.chat.expectMessageVisible(`${alice.nick} sets mode +m`);

      await bob.chat.sendMessage(text);
      const failedRow = bob.chat.messageRowByText(text);
      await expect(failedRow).toHaveAttribute('data-msg-status', 'failed');
      await expect(failedRow.getByTestId('retry-message')).toBeVisible();

      await bob.chat.openMessageContextMenu(text);
      await bob.chat.contextDeleteMenuItem.click();

      await expect(bob.chat.messageRows.filter({ hasText: text })).toHaveCount(0);
      await expect(bob.chat.messageList.getByTestId('retry-message')).toHaveCount(0);
      await expect(bob.chat.chatInput).toBeEnabled();
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
