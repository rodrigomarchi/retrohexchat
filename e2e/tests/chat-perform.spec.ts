import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'perf'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: Page,
  prefix = 'perf',
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
  page: Page,
  chat: ChatPage,
  nick: string,
  password: string,
) {
  const connect = new ConnectPage(page);

  await chat.disconnect();
  await connect.open();
  await connect.enterNickname(nick);
  await connect.authenticateWithPassword(password);
  await chat.waitUntilConnected();
}

test.describe('Perform commands', () => {
  test('/perform add/list/move/remove/clear update command output (L6)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'perfc');
    const channel = uniqueChannel('pfcrud');
    const awayMessage = `perform-away-${Date.now()}`;

    await chat.sendMessage(`/perform add /join ${channel}`);
    await chat.expectMessageVisible(`* Added to perform list: /join ${channel}`);

    await chat.sendMessage(`/perform add /away ${awayMessage}`);
    await chat.expectMessageVisible(
      `* Added to perform list: /away ${awayMessage}`,
    );

    await chat.sendMessage('/clear');
    await chat.sendMessage('/perform list');
    await chat.expectMessageVisible(`0: /join ${channel}`);
    await chat.expectMessageVisible(`1: /away ${awayMessage}`);

    await chat.sendMessage('/perform move 1 0');
    await chat.expectMessageVisible('* Moved command from position 1 to 0');

    await chat.sendMessage('/clear');
    await chat.sendMessage('/perform list');
    await chat.expectMessageVisible(`0: /away ${awayMessage}`);
    await chat.expectMessageVisible(`1: /join ${channel}`);

    await chat.sendMessage('/perform remove 1');
    await chat.expectMessageVisible('* Removed command at position 1');

    await chat.sendMessage('/clear');
    await chat.sendMessage('/perform list');
    await chat.expectMessageVisible(`0: /away ${awayMessage}`);
    await chat.expectMessageHidden(`/join ${channel}`);

    await chat.sendMessage('/perform clear');
    await chat.expectMessageVisible('* Perform list cleared');

    await chat.sendMessage('/clear');
    await chat.sendMessage('/perform list');
    await chat.expectMessageVisible('Your perform list is empty');
  });

  test('perform entries execute on reconnect without stealing active tab focus (L7)', async ({
    page,
  }) => {
    const password = 'pass12345';
    const { chat, nick } = await signedInUser(page, 'perfr', password);
    const channel = uniqueChannel('pfauto');
    const lobbyMarker = `perform-lobby-marker-${Date.now()}`;

    await chat.switchToTab('#lobby');
    await chat.sendMessage(lobbyMarker);
    await chat.expectMessageVisible(lobbyMarker);

    await chat.sendMessage(`/perform add /join ${channel}`);
    await chat.expectMessageVisible(`* Added to perform list: /join ${channel}`);
    await page.waitForTimeout(500);

    await reconnectRegisteredUser(page, chat, nick, password);

    await chat.expectTabVisible(channel);
    await chat.expectTabSelected('#lobby');
    await chat.expectMessageVisible(lobbyMarker);

    await chat.switchToStatusTab();
    await chat.expectStatusMessageVisible(`* Performing: /join ${channel}`);
    await chat.expectStatusMessageHidden(`* Auto-joining ${channel}...`);
  });

  test('sensitive perform commands are masked and unsafe commands are rejected (L8)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'perfs');
    const secret = `secret-${Date.now()}`;

    await chat.sendMessage(`/perform add /ns identify ${secret}`);
    await chat.expectMessageVisible('* Added to perform list: /ns identify ****');

    await chat.sendMessage('/perform list');
    await chat.expectMessageVisible('0: /ns identify ****');
    await expect(chat.messageList.getByText(secret, { exact: false })).toHaveCount(
      0,
    );

    await chat.sendMessage('/perform add /perform list');
    await chat.expectMessageVisible(
      'That command cannot be added to the perform list',
    );

    await chat.sendMessage('/perform add /autojoin add #blocked');
    await chat.expectMessageVisible(
      'That command cannot be added to the perform list',
    );

    await chat.sendMessage('/perform add not-a-slash-command');
    await chat.expectMessageVisible('Invalid command. Commands must start with /');
  });
});
