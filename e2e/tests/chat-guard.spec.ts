import { test, expect } from '@playwright/test';

test.describe('Chat route guard', () => {
  test('direct /chat access without session bounces to /connect (H)', async ({
    page,
  }) => {
    await page.goto('/chat');
    await expect(page).toHaveURL(/\/connect(\?.*)?$/);
  });
});
