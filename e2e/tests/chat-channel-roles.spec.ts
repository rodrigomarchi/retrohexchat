import { Browser, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'role'): string {
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
  await userB.chat.expectNickInList(userA.nick);

  return {
    ctxA,
    ctxB,
    chatA: userA.chat,
    chatB: userB.chat,
    nickA: userA.nick,
    nickB: userB.nick,
  };
}

test.describe('Channel roles', () => {
  test('first user in a unique channel is channel owner (I1)', async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page, 'owner');
    const channel = uniqueChannel('owner');

    await chat.sendMessage(`/join ${channel}`);

    await chat.expectNickInList(nick);
    await chat.expectNickRole(nick, 'owner');
  });

  test('/op, /deop, /voice, and /devoice update nicklist role in realtime (I2)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('roles');
    const { ctxA, ctxB, chatA, chatB, nickB } =
      await setupTwoUsersInChannel(browser, channel);

    try {
      await chatA.sendMessage(`/op ${nickB}`);
      await chatA.expectNickRole(nickB, 'operator');
      await chatB.expectNickRole(nickB, 'operator');

      await chatA.sendMessage(`/deop ${nickB}`);
      await chatA.expectNickRole(nickB, 'regular');
      await chatB.expectNickRole(nickB, 'regular');

      await chatA.sendMessage(`/voice ${nickB}`);
      await chatA.expectNickRole(nickB, 'voiced');
      await chatB.expectNickRole(nickB, 'voiced');

      await chatA.sendMessage(`/devoice ${nickB}`);
      await chatA.expectNickRole(nickB, 'regular');
      await chatB.expectNickRole(nickB, 'regular');
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
