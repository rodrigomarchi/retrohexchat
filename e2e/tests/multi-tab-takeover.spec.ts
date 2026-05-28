import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

test.describe('Multi-tab takeover', () => {
  test('same nick connecting from a second context kicks the first (K)', async ({
    browser,
  }) => {
    // Two separate browser contexts so they don't share cookies/session.
    const ctxA = await browser.newContext();
    const ctxB = await browser.newContext();
    const pageA = await ctxA.newPage();
    const pageB = await ctxB.newPage();

    const nick = uniqueNickname();
    const pw = 'testpass123';

    try {
      // Phase 1: A registers the nick and enters chat.
      const connectA = new ConnectPage(pageA);
      const chatA = new ChatPage(pageA);
      await connectA.open();
      await connectA.enterNickname(nick);
      await connectA.registerWithPassword(pw);
      await chatA.waitUntilConnected();

      // Phase 2: B authenticates as the SAME nick — server-side
      // ChatLive.mount broadcasts {:force_disconnect, ...} on the
      // user:<nick> PubSub topic before subscribing, which A is already
      // subscribed to.
      const connectB = new ConnectPage(pageB);
      await connectB.open();
      await connectB.enterNickname(nick);
      await connectB.authenticateWithPassword(pw);
      await expect(pageB).toHaveURL(/\/chat(\?.*)?$/);

      // Phase 3: A receives the broadcast and is redirected through
      // /chat/session/clear -> /connect?reason=<message>. The reason
      // message contains "Session ended — logged in from another window".
      await expect(pageA).toHaveURL(/\/connect\?reason=/);
      const banner = pageA.getByTestId('session-alert');
      await expect(banner).toBeVisible();
      await expect(banner).toContainText('Session ended');
      await expect(banner).toContainText('logged in from another window');
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
