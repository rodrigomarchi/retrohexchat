import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'recon'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'recon') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe('Chat reconnect and reload', () => {
  test('browser reload restores the current chat session cleanly (P8)', async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page);
    const channel = uniqueChannel();
    const beforeReload = `reload-before-${Date.now()}`;
    const afterReload = `reload-after-${Date.now()}`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);
    await chat.expectTabSelected(channel);

    await chat.sendMessage(beforeReload);
    await chat.expectMessageVisible(beforeReload);

    await page.waitForFunction(
      ([expectedNick, expectedChannel]) => {
        const raw = localStorage.getItem('rhc_reconnect_state');
        if (!raw) return false;

        const state = JSON.parse(raw);
        return (
          state.nickname === expectedNick &&
          state.active_channel === expectedChannel &&
          state.channels.includes(expectedChannel)
        );
      },
      [nick, channel],
    );

    await page.reload();
    await chat.waitUntilConnected();

    await chat.expectTabVisible(channel);
    await expect(chat.tab(channel)).toHaveAttribute('aria-selected', 'true', {
      timeout: 10_000,
    });
    await chat.expectMessageVisible(beforeReload, 10_000);

    await chat.sendMessage(afterReload);
    await chat.expectMessageVisible(afterReload);
  });

  test('connection loss disables input without losing typed draft (P9)', async ({
    context,
    page,
  }) => {
    test.setTimeout(45_000);

    const { chat } = await signedInUser(page, 'drop');
    const draft = `draft survives reconnect ${Date.now()}`;

    await chat.chatInput.fill(draft);
    await expect(chat.chatSendButton).toBeEnabled();

    try {
      await context.setOffline(true);

      await expect(chat.connectionBanner).toHaveClass(
        /connection-banner--visible/,
        { timeout: 5_000 },
      );
      await expect(chat.chatInput).toBeDisabled();
      await expect(chat.chatInput).toHaveValue(draft);

      await expect(chat.reconnectOverlay).toHaveClass(
        /reconnect-overlay--visible/,
        { timeout: 10_000 },
      );
      await expect(chat.reconnectOverlayAction).toHaveText('Cancel');
      await expect(chat.chatInput).toHaveValue(draft);

      await context.setOffline(false);
      await expect(chat.connectionBanner).toContainText('Reconectado', {
        timeout: 15_000,
      });
      await page.waitForFunction(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        () => !!(window as any).liveSocket?.isConnected?.(),
        { timeout: 10_000 },
      );

      await expect(chat.chatInput).toBeEnabled();
      await expect(chat.chatInput).toHaveValue(draft);
      await expect(chat.chatSendButton).toBeEnabled();

      await chat.chatInput.press('Enter');
      await chat.expectMessageVisible(draft);
    } finally {
      await context.setOffline(false);
    }
  });
});
