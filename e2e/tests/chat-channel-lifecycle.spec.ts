import { Browser, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'h'): string {
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

  const userA = await signedInUser(pageA, 'a');
  const userB = await signedInUser(pageB, 'b');

  await userA.chat.sendMessage(`/join ${channel}`);
  await userA.chat.expectTabVisible(channel);

  await userB.chat.sendMessage(`/join ${channel}`);
  await userB.chat.expectTabVisible(channel);
  await userA.chat.switchToTab(channel);
  await userA.chat.expectNickInList(userB.nick);

  return {
    ctxA,
    ctxB,
    chatA: userA.chat,
    chatB: userB.chat,
    nickB: userB.nick,
  };
}

test.describe('Channel lifecycle', () => {
  test('/part #other from #lobby removes only #other and keeps #lobby focused (H4)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);
    const otherChannel = uniqueChannel('other');
    const lobbyMarker = `still-in-lobby-${Date.now()}`;

    await chat.sendMessage(`/join ${otherChannel}`);
    await chat.expectTabVisible(otherChannel);

    await chat.switchToTab('#lobby');
    await chat.sendMessage(lobbyMarker);
    await chat.expectMessageVisible(lobbyMarker);

    await chat.switchToTab('#lobby');
    await chat.sendMessage(`/part ${otherChannel}`);

    await chat.expectTabHidden(otherChannel);
    await chat.expectMessageVisible(lobbyMarker);
  });

  test('/leave #room reason works as /part, removes tab, and broadcasts reason (H3)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('leave');
    const reason = `bye-${Date.now()}`;
    const { ctxA, ctxB, chatA, chatB, nickB } = await setupTwoUsersInChannel(
      browser,
      channel,
    );

    try {
      await chatB.sendMessage(`/leave ${channel} ${reason}`);

      await chatB.expectTabHidden(channel);
      await chatA.expectMessageVisible(`${nickB} has left (${reason})`);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test('/clear clears only the active channel window (H5)', async ({ page }) => {
    const { chat } = await signedInUser(page);
    const channel = uniqueChannel('clear');
    const roomMessage = `room-message-${Date.now()}`;
    const lobbyMessage = `lobby-message-${Date.now()}`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.sendMessage(roomMessage);
    await chat.expectMessageVisible(roomMessage);

    await chat.switchToTab('#lobby');
    await chat.sendMessage(lobbyMessage);
    await chat.expectMessageVisible(lobbyMessage);

    await chat.switchToTab(channel);
    await chat.sendMessage('/clear');
    await chat.expectMessageHidden(roomMessage);

    await chat.switchToTab('#lobby');
    await chat.expectMessageVisible(lobbyMessage);
  });
});
