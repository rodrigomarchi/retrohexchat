import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

test.describe('Welcome message', () => {
  test('on join, the server welcome banner is visible to the user (A5)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await connect.registerWithPassword('pass12345');
    await chat.waitUntilConnected();

    // show_welcome_message pushes "Welcome to <server name>!" plus help
    // hints onto the Status tab (mIRC-style: server-level messages don't
    // appear in channel tabs). The user lands on #lobby by default, so we
    // explicitly switch to Status to view what the server announced.
    await chat.switchToStatusTab();
    await expect(page.getByText(/Welcome to/)).toBeVisible();
  });
});
