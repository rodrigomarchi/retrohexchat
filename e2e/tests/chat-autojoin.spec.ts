import { Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'auto'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: Page,
  prefix = 'auto',
  password = 'pass12345',
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, nick, password };
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

test.describe('Auto-join commands', () => {
  test('/autojoin add/list/remove/clear works and invalid channels are rejected (L9)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'autoc');
    const channel = uniqueChannel('ajcrud');
    const secondChannel = uniqueChannel('ajmore');

    await chat.sendMessage('/autojoin add not-a-channel');
    await chat.expectMessageVisible('Channel name must start with #');

    await chat.sendMessage(`/autojoin add ${channel} secret-key`);
    await chat.expectMessageVisible(`* Added to auto-join list: ${channel}`);

    await chat.sendMessage('/clear');
    await chat.sendMessage('/autojoin list');
    await chat.expectMessageVisible(`${channel} (key: ****)`);

    await chat.sendMessage(`/autojoin remove ${channel}`);
    await chat.expectMessageVisible(`* Removed ${channel} from auto-join list`);

    await chat.sendMessage('/clear');
    await chat.sendMessage('/autojoin list');
    await chat.expectMessageVisible('Your auto-join list is empty');

    await chat.sendMessage(`/autojoin add ${channel}`);
    await chat.expectMessageVisible(`* Added to auto-join list: ${channel}`);
    await chat.sendMessage(`/autojoin add ${secondChannel}`);
    await chat.expectMessageVisible(
      `* Added to auto-join list: ${secondChannel}`,
    );

    await chat.sendMessage('/autojoin clear');
    await chat.expectMessageVisible('* Auto-join list cleared');

    await chat.sendMessage('/clear');
    await chat.sendMessage('/autojoin list');
    await chat.expectMessageVisible('Your auto-join list is empty');
  });

  test('joining a unique channel auto-adds it; part removes it (L10)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'autoj');
    const channel = uniqueChannel('ajjoin');

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage('/autojoin list');
    await chat.expectMessageVisible(channel);

    await chat.sendMessage(`/part ${channel}`);
    await chat.expectTabHidden(channel);

    await chat.sendMessage('/clear');
    await chat.sendMessage('/autojoin list');
    await chat.expectMessageVisible('Your auto-join list is empty');
  });

  test('autojoin entries execute on reconnect without stealing active window focus (L11)', async ({
    page,
  }) => {
    const password = 'pass12345';
    const { chat, nick } = await signedInUser(page, 'autor', password);
    const channel = uniqueChannel('ajre');
    const lobbyMarker = `autojoin-lobby-marker-${Date.now()}`;

    await chat.switchToTab('#lobby');
    await chat.sendMessage(lobbyMarker);
    await chat.expectMessageVisible(lobbyMarker);

    await chat.sendMessage(`/autojoin add ${channel}`);
    await chat.expectMessageVisible(`* Added to auto-join list: ${channel}`);
    await page.waitForTimeout(500);

    await reconnectRegisteredUser(page, chat, nick, password);

    await chat.expectTabVisible(channel);
    await chat.expectTabSelected('#lobby');
    await chat.expectMessageVisible(lobbyMarker);

    await chat.switchToStatusTab();
    await chat.expectStatusMessageVisible(`* Auto-joining ${channel}...`);
  });
});
