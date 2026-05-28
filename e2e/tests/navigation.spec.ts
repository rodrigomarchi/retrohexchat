import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';

test.describe('Connect navigation', () => {
  test('Back from :register returns to :nickname and preserves the nick (G)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const nick = uniqueNickname();

    await connect.open();
    await connect.enterNickname(nick);
    await expect(connect.registerPasswordInput).toBeVisible();

    await connect.clickBack();
    await expect(connect.nicknameInput).toBeVisible();
    await expect(connect.nicknameInput).toHaveValue(nick);
  });
});
