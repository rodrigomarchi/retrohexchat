import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

test.describe('Basic chat commands', () => {
  test('/me <action> renders as an action-style line containing the user nick (A4)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    const nick = uniqueNickname();

    await connect.open();
    await connect.enterNickname(nick);
    await connect.registerWithPassword('pass12345');
    await chat.waitUntilConnected();

    const action = `dances ${Date.now()}`;
    await chat.sendMessage(`/me ${action}`);

    // The /me command renders as an action message; the user-visible
    // result should contain both the nick and the action text.
    await chat.expectMessageVisible(action);
    await chat.expectMessageVisible(nick);
  });
});
