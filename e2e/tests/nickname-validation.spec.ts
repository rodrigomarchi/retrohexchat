import { test, expect } from '@playwright/test';
import { ConnectPage } from '../pages/ConnectPage';

test.describe('Nickname validation', () => {
  test('empty nickname keeps the Connect button disabled (C1)', async ({ page }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await expect(connect.nicknameInput).toHaveValue('');
    await expect(connect.connectButton).toBeDisabled();
  });

  test('input enforces 16-char maxlength on nickname (C2)', async ({ page }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    // Real typing (not programmatic .fill()) so the HTML maxlength is enforced.
    await connect.nicknameInput.pressSequentially('abcdefghijklmnopqrst');
    const value = await connect.nicknameInput.inputValue();
    expect(value.length).toBe(16);
  });

  test('nickname with a space shows inline error and disables Connect (C3)', async ({ page }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.typeNickname('bad nick');
    await expect(connect.nicknameError).toContainText('Nickname cannot contain spaces');
    await expect(connect.connectButton).toBeDisabled();
  });

  test('nickname starting with a digit shows inline error (C4)', async ({ page }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.typeNickname('1invalid');
    await expect(connect.nicknameError).toContainText(
      'Nickname must start with a letter or special character',
    );
    await expect(connect.connectButton).toBeDisabled();
  });
});
