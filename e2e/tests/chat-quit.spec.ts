import { Browser, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'quit'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: import('@playwright/test').Page,
  prefix = 'e2e',
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return { chat, nick };
}

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const ctxA = await browser.newContext();
  const ctxB = await browser.newContext();
  const pageA = await ctxA.newPage();
  const pageB = await ctxB.newPage();

  const userA = await signedInUser(pageA, 'qa');
  const userB = await signedInUser(pageB, 'qb');

  await userA.chat.sendMessage(`/join ${channel}`);
  await userA.chat.expectTabVisible(channel);

  await userB.chat.sendMessage(`/join ${channel}`);
  await userB.chat.expectTabVisible(channel);
  await userA.chat.switchToTab(channel);
  await userA.chat.expectNickInList(userB.nick);

  return {
    ctxA,
    ctxB,
    pageB,
    chatA: userA.chat,
    chatB: userB.chat,
    nickB: userB.nick,
  };
}

test.describe('Quit command', () => {
  test('/quit reason navigates self to connect and broadcasts the reason (H12)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('quit');
    const reason = `quit-${Date.now()}`;
    const { ctxA, ctxB, pageB, chatA, chatB, nickB } =
      await setupTwoUsersInChannel(browser, channel);

    try {
      await chatB.sendMessage(`/quit ${reason}`);

      await expect(pageB).toHaveURL(/\/connect(\?.*)?$/);
      await chatA.expectMessageVisible(`${nickB} has left (${reason})`);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
