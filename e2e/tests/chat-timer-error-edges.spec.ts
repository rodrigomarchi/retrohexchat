import { Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'timererr'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

function uniqueTimer(prefix = 'tmerr'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signedInUser(page: Page, prefix = 'timererr') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

test.describe('Timer error edges', () => {
  test('timer whose creation window disappears reports an error and is removed (Y7)', async ({
    page,
  }) => {
    const chat = await signedInUser(page, 'y7');
    const origin = uniqueChannel('y7src');
    const active = uniqueChannel('y7dst');
    const timerName = uniqueTimer('y7');
    const marker = `timer-invalid-${Date.now()}`;

    await chat.sendMessage(`/join ${origin}`);
    await chat.expectTabVisible(origin);
    await chat.sendMessage(`/join ${active}`);
    await chat.expectTabVisible(active);

    await chat.switchToTab(origin);
    await chat.sendMessage(`/timer ${timerName} 2 /me ${marker}`);
    await chat.expectMessageVisible(`* Timer '${timerName}' set`);

    await chat.switchToTab(active);
    await chat.sendMessage(`/part ${origin}`);
    await chat.expectTabHidden(origin);
    await chat.expectTabSelected(active);

    await chat.expectMessageVisible(
      `* Timer '${timerName}' target window is no longer available`,
      6_000,
    );
    await chat.expectMessageHidden(marker);

    await chat.sendMessage('/timer list');
    await chat.expectMessageVisible('No active timers.');
  });
});
