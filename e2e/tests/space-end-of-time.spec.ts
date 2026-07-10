import { test, expect } from '@playwright/test';
import { newSignedInUser, closeUsers, uniqueChannel, TestUser } from '../helpers/chatUsers';

// The direct-message space renders the cozy "End of Time" cosmic-island scene.
test.describe('End of Time private space', () => {
  test('a PM space mounts the End of Time scene with the chosen avatar', async ({ browser }) => {
    const alice: TestUser = await newSignedInUser(browser, 'eota');
    const bob: TestUser = await newSignedInUser(browser, 'eotb');
    try {
      const channel = uniqueChannel('eot');
      await alice.chat.sendMessage(`/join ${channel}`);
      await bob.chat.sendMessage(`/join ${channel}`);

      // Alice opens a private conversation with Bob and switches to it.
      await alice.chat.sendMessage(`/msg ${bob.nick} hey`);

      const page = alice.page;
      await page.getByTestId(`pm-${bob.nick}`).click();
      await expect(page.getByPlaceholder(new RegExp(`Message to ${bob.nick}`))).toBeVisible();

      const spaceTab = page.locator(
        '[data-testid="topic-bar"] [data-testid="channel-view-tabs"] button[phx-value-view="space"]',
      );
      await expect(spaceTab).toBeVisible();
      await spaceTab.click();

      // Character picker gates the DM canvas.
      await expect(page.getByTestId('space-character-select')).toBeVisible();
      await page.getByTestId('space-avatar-knight').click();

      const shell = page.locator(
        '[data-testid="channel-space-shell"][data-space-mode="direct_message"][data-avatar="knight"]',
      );
      await expect(shell).toBeVisible();
      const canvas = page.locator('[data-testid="channel-space-shell"] canvas');
      await expect(canvas).toBeVisible();

      // The world draws the island + props + avatar onto the canvas.
      await expect
        .poll(
          () =>
            canvas.evaluate((el: HTMLCanvasElement) => {
              const ctx = el.getContext('2d');
              if (!ctx || !el.width || !el.height) return 0;
              const { data } = ctx.getImageData(0, 0, el.width, el.height);
              let sum = 0;
              for (let i = 0; i < data.length; i += 997) sum = (sum + data[i]) % 1_000_000;
              return sum;
            }),
          { timeout: 10_000 },
        )
        .toBeGreaterThan(0);

      await page.screenshot({ path: 'test-results/end-of-time.png' });
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
