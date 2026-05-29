import { Browser, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'perm'): string {
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

  const userA = await signedInUser(pageA, 'own');
  const userB = await signedInUser(pageB, 'reg');

  await userA.chat.sendMessage(`/join ${channel}`);
  await userB.chat.sendMessage(`/join ${channel}`);

  await userA.chat.expectNickInList(userB.nick);
  await userB.chat.expectNickRole(userB.nick, 'regular');

  return {
    ctxA,
    ctxB,
    chatA: userA.chat,
    chatB: userB.chat,
    nickA: userA.nick,
  };
}

test.describe('Channel permissions', () => {
  test('regular users cannot change protected modes or kick users (I3)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('perm');
    const { ctxA, ctxB, chatA, chatB, nickA } =
      await setupTwoUsersInChannel(browser, channel);

    try {
      await chatB.sendMessage('/mode +m');
      await chatB.expectMessageVisible(
        'You must be a channel operator to change modes',
      );

      await chatB.sendMessage(`/kick ${nickA} no privileges`);
      await chatB.expectMessageVisible(
        'You must be a channel operator to kick users',
      );

      await chatA.expectNickInList(nickA);
      await chatB.expectNickInList(nickA);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
