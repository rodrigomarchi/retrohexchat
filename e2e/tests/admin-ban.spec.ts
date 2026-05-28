import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

// TestAdmin is hard-coded in config/e2e.exs as a server administrator.
// Once it registers with NickServ it is automatically identified and
// gains admin powers (ServerRoles.admin? returns true).
const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

test.describe('Admin ban', () => {
  test('admin /admin user ban -> victim force-disconnected with "Server banned" banner (M)', async ({
    browser,
  }) => {
    const ctxAdmin = await browser.newContext();
    const ctxVictim = await browser.newContext();
    const pageAdmin = await ctxAdmin.newPage();
    const pageVictim = await ctxVictim.newPage();

    const victimNick = uniqueNickname();
    const victimPw = 'victimpw123';

    try {
      // Admin connects (signIn handles both first-time register and
      // subsequent auth, since TestAdmin persists across e2e DB state).
      const adminConnect = new ConnectPage(pageAdmin);
      const adminChat = new ChatPage(pageAdmin);
      await adminConnect.open();
      await adminConnect.signIn(ADMIN_NICK, ADMIN_PW);
      await adminChat.waitUntilConnected();

      // Victim connects with a fresh nick.
      const victimConnect = new ConnectPage(pageVictim);
      const victimChat = new ChatPage(pageVictim);
      await victimConnect.open();
      await victimConnect.enterNickname(victimNick);
      await victimConnect.registerWithPassword(victimPw);
      await victimChat.waitUntilConnected();

      // Admin bans the victim. Admin.ban_user broadcasts
      // {:force_disconnect, %{reason: "Server banned: ..."}} on the
      // user:<victim> PubSub topic.
      await adminChat.sendMessage(`/admin user ban ${victimNick}`);

      // Victim's membership pubsub_handler redirects through
      // /chat/session/clear -> /connect?reason=<message>.
      await expect(pageVictim).toHaveURL(/\/connect\?reason=/);
      const banner = pageVictim.getByTestId('session-alert');
      await expect(banner).toBeVisible();
      await expect(banner).toContainText('Server banned');
    } finally {
      await ctxAdmin.close();
      await ctxVictim.close();
    }
  });
});
