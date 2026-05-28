import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';

test.describe('Connect flow', () => {
  test('brand-new user registers a nickname and lands on /chat', async ({ page }) => {
    const connect = new ConnectPage(page);
    const nick = uniqueNickname();

    await connect.open();
    await connect.enterNickname(nick);
    await connect.registerWithPassword('testpass123');

    // After registration ConnectLive's JS hook posts a hidden form to
    // /chat/session, SessionController stores the nickname, and Phoenix
    // redirects to /chat where ChatLive mounts and sets the page title.
    await expect(page).toHaveURL(/\/chat(\?.*)?$/);
    await expect(page).toHaveTitle('RetroHexChat');
  });
});
