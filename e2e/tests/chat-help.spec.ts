import { test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: import('@playwright/test').Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname());
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return chat;
}

test.describe('Help command', () => {
  test('/help lists available commands in the active message list', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.sendMessage('/help');

    await chat.expectMessageVisible('Available commands:');
    await chat.expectMessageVisible('Type /help');
  });
});
