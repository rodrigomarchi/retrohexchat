import { Browser, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signInAdmin(page: import('@playwright/test').Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.signIn('TestAdmin', 'adminpass1');
  await chat.waitUntilConnected();
  return chat;
}

async function signedInUser(page: import('@playwright/test').Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.signIn(uniqueNickname('motd'), 'pass12345');
  await chat.waitUntilConnected();
  return chat;
}

test.describe('Server messages', () => {
  test('/setmotd, /motd, and new connections show the admin MOTD (H11)', async ({
    browser,
  }) => {
    const motd = `E2E MOTD ${Date.now()}`;
    const adminContext = await browser.newContext();
    const userContext = await browser.newContext();
    const adminPage = await adminContext.newPage();
    const userPage = await userContext.newPage();
    const adminChat = await signInAdmin(adminPage);

    try {
      await adminChat.sendMessage('/clearmotd');
      await adminChat.sendMessage(`/setmotd ${motd}`);
      await adminChat.expectMessageVisible('MOTD has been updated.');

      await adminChat.sendMessage('/motd');
      await adminChat.switchToStatusTab();
      await adminChat.expectStatusMessageVisible(motd);

      const userChat = await signedInUser(userPage);
      await userChat.switchToStatusTab();
      await userChat.expectStatusMessageVisible(motd);
    } finally {
      await adminChat.sendMessage('/clearmotd');
      await adminContext.close();
      await userContext.close();
    }
  });
});
