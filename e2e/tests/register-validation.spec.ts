import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';

test.describe('Register step validation', () => {
  test('passwords that do not match show inline error (E)', async ({ page }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await expect(connect.registerPasswordInput).toBeVisible();

    await connect.registerPasswordInput.fill('correct-pass');
    await connect.registerPasswordConfirmInput.fill('different-pass');
    await connect.registerButton.click();

    await expect(connect.registerError).toContainText('Passwords do not match');
  });

  test('password shorter than 5 chars shows inline error (F)', async ({ page }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());

    await connect.registerPasswordInput.fill('abc');
    await connect.registerPasswordConfirmInput.fill('abc');
    await connect.registerButton.click();

    await expect(connect.registerError).toContainText(
      'Password must be at least 5 characters',
    );
  });
});
