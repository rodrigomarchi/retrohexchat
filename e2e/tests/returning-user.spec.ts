import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

test.describe('Returning user (registered nick)', () => {
  test('register, log out, reconnect with correct password lands on /chat (B)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    const nick = uniqueNickname();
    const pw = 'testpass123';

    // Phase 1: brand-new user registers and lands in chat.
    await connect.open();
    await connect.enterNickname(nick);
    await connect.registerWithPassword(pw);
    await chat.waitUntilConnected();

    // Phase 2: log out via the File menu.
    await chat.disconnect();

    // Phase 3: reconnect with the same nick — now goes through :password.
    await connect.open();
    await connect.enterNickname(nick);
    await connect.authenticateWithPassword(pw);

    await expect(page).toHaveURL(/\/chat(\?.*)?$/);
    await expect(page).toHaveTitle('RetroHexChat');
  });

  test('wrong password shows error, retry with correct password works (D)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    const nick = uniqueNickname();
    const pw = 'testpass123';

    // Set up: register a nick then log out.
    await connect.open();
    await connect.enterNickname(nick);
    await connect.registerWithPassword(pw);
    await chat.waitUntilConnected();
    await chat.disconnect();

    // Try to reconnect with the wrong password.
    await connect.open();
    await connect.enterNickname(nick);
    await expect(connect.authPasswordInput).toBeVisible();

    await connect.authPasswordInput.fill('wrong-password');
    await connect.authButton.click();
    await expect(connect.authError).toContainText('Incorrect password');

    // The server clears the password field on failure; typing the right
    // one fires validate_password which also clears the error.
    await connect.authPasswordInput.fill(pw);
    await connect.authButton.click();

    await expect(page).toHaveURL(/\/chat(\?.*)?$/);
  });
});
