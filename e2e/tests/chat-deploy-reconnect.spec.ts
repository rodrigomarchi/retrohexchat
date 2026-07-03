import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

// Reproduces what a user sees when the server restarts during a deploy: the
// LiveView socket drops, the reconnect UI escalates, and — when the socket comes
// back — the server re-runs the full connected `mount/3`, replaying the login
// sequence (connect sound, MOTD, welcome, #lobby rejoin, "* Restoring session…").
//
// A `page.reload()` drives the exact same connected `mount_connected_chat` path
// the deploy reconnect triggers on the server, so it is a deterministic proxy for
// the cold remount (no flaky server-restart / heartbeat-timeout dependency).

async function signedInUser(page: Page, prefix = 'depl') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe('Deploy reconnect', () => {
  // ── The client-side outage UX ──────────────────────────────────────────
  // A routine deploy is a short outage: the user should see the unobtrusive
  // banner, but NOT get trapped behind the full-screen "Connection Lost" modal
  // (which now only escalates after a much longer wait).
  test('a short outage shows the banner but not the intrusive modal (BA1)', async ({
    browser,
  }) => {
    test.setTimeout(45_000);
    const ctx: BrowserContext = await browser.newContext();
    const page = await ctx.newPage();

    try {
      const { chat } = await signedInUser(page);
      // A pending outbound push (typing) makes LiveView notice the dead socket
      // promptly once we cut the network, instead of waiting for a heartbeat.
      await chat.chatInput.fill(`draft ${Date.now()}`);

      await ctx.setOffline(true);

      // The yellow banner appears quickly…
      await expect(chat.connectionBanner).toHaveClass(
        /connection-banner--visible/,
        { timeout: 12_000 },
      );
      // …but the dim full-screen modal must NOT take over during a short outage.
      await page.waitForTimeout(7_000);
      await expect(chat.reconnectOverlay).not.toHaveClass(
        /reconnect-overlay--visible/,
      );
      await page.screenshot({
        path: 'test-results/deploy-reconnect-banner.png',
        fullPage: true,
      });

      await ctx.setOffline(false);
      await expect(chat.connectionBanner).toContainText(
        /Reconnected|Reconectado/,
        { timeout: 20_000 },
      );
      await chat.waitUntilConnected();
    } finally {
      await ctx.setOffline(false).catch(() => {});
      await ctx.close();
    }
  });

  // ── The server-side login-sequence replay ──────────────────────────────
  // The bug: a reconnect is NOT seamless. The cold remount replays the login
  // sequence, so the user sees "* Restoring session…" and a fresh #lobby join
  // burst every deploy. A reconnect should restore the session silently.
  test('a cold remount must not replay the login sequence (BA2)', async ({
    browser,
  }) => {
    test.setTimeout(45_000);
    const ctx: BrowserContext = await browser.newContext();
    const page = await ctx.newPage();

    try {
      const { chat } = await signedInUser(page);

      const marker = `deploy marker ${Date.now()}`;
      await chat.sendMessage(marker);
      await chat.expectMessageVisible(marker);

      // Cold remount — same server mount path a deploy reconnect runs.
      await page.reload();
      await chat.waitUntilConnected();
      await page.screenshot({
        path: 'test-results/deploy-reconnect-after.png',
        fullPage: true,
      });

      // The user's own message survives (loaded from the DB) — history intact.
      await chat.expectMessageVisible(marker);

      // A seamless reconnect must not surface the restore/login burst: no
      // "Restoring session…" and no replayed "You are now identified as" greeting.
      await expect(page.getByText(/Restoring session/i)).toHaveCount(0);
      await expect(page.getByText(/You are now identified as/i)).toHaveCount(0);
    } finally {
      await ctx.close();
    }
  });
});
