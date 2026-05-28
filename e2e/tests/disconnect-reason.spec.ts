import { test, expect } from '@playwright/test';

test.describe('Disconnect reason banners', () => {
  test('?reason=expired surfaces "Session expired" (I)', async ({ page }) => {
    await page.goto('/connect?reason=expired');
    const banner = page.getByTestId('session-alert');
    await expect(banner).toBeVisible();
    await expect(banner).toContainText('Session expired');
  });

  test('?reason=disconnected surfaces "Session ended" (J)', async ({ page }) => {
    await page.goto('/connect?reason=disconnected');
    const banner = page.getByTestId('session-alert');
    await expect(banner).toBeVisible();
    await expect(banner).toContainText('Session ended');
  });
});
