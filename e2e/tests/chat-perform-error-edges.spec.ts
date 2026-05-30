import { Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'perferr'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: Page,
  prefix = 'perferr',
  password = 'pass12345',
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, nick, password };
}

async function reconnectRegisteredUser(
  chat: ChatPage,
  connect: ConnectPage,
  nick: string,
  password: string,
) {
  await chat.disconnect();
  await connect.open();
  await connect.enterNickname(nick);
  await connect.authenticateWithPassword(password);
  await chat.waitUntilConnected();
}

test.describe('Perform error edges', () => {
  test('failed perform command on reconnect reports error and later entries continue (Y8)', async ({
    page,
  }) => {
    const { chat, connect, nick, password } = await signedInUser(page, 'y8');
    const missingChannel = uniqueChannel('y8missing');
    const validChannel = uniqueChannel('y8valid');

    await chat.sendMessage(`/perform add /part ${missingChannel}`);
    await chat.expectMessageVisible(
      `* Added to perform list: /part ${missingChannel}`,
    );

    await chat.sendMessage(`/perform add /join ${validChannel}`);
    await chat.expectMessageVisible(
      `* Added to perform list: /join ${validChannel}`,
    );

    await reconnectRegisteredUser(chat, connect, nick, password);

    await chat.expectTabVisible(validChannel);
    await chat.expectTabSelected('#lobby');

    await chat.switchToStatusTab();
    await chat.expectStatusMessageVisible(`* Performing: /part ${missingChannel}`);
    await chat.expectStatusMessageVisible(`You are not in ${missingChannel}`);
    await chat.expectStatusMessageVisible(`* Performing: /join ${validChannel}`);
  });
});
