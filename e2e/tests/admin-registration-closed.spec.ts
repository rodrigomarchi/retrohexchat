import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

test.describe('Admin closes registration', () => {
  test('/admin server set registration closed blocks new registrations (N)', async ({
    browser,
  }) => {
    const ctxAdmin = await browser.newContext();
    const ctxNewUser = await browser.newContext();
    const pageAdmin = await ctxAdmin.newPage();
    const pageNewUser = await ctxNewUser.newPage();

    const newUserNick = uniqueNickname();
    const newUserPw = 'pass12345';

    try {
      const adminConnect = new ConnectPage(pageAdmin);
      const adminChat = new ChatPage(pageAdmin);
      await adminConnect.open();
      await adminConnect.signIn(ADMIN_NICK, ADMIN_PW);
      await adminChat.waitUntilConnected();

      try {
        // Close registration.
        await adminChat.sendMessage('/admin server set registration closed');
        // Give the LV a moment to apply the setting before the new user
        // hits the register endpoint.
        await pageAdmin.waitForTimeout(500);

        // New user attempts to register.
        const userConnect = new ConnectPage(pageNewUser);
        await userConnect.open();
        await userConnect.enterNickname(newUserNick);
        await expect(userConnect.registerPasswordInput).toBeVisible();
        await userConnect.registerPasswordInput.fill(newUserPw);
        await userConnect.registerPasswordConfirmInput.fill(newUserPw);
        await userConnect.registerButton.click();

        // NickServ.register returns the closed-registration error which
        // ConnectLive surfaces on the :register step.
        await expect(userConnect.registerError).toContainText(
          'Registration is currently closed',
        );
      } finally {
        // ALWAYS re-open registration so this destructive test doesn't
        // leak state into subsequent runs/specs.
        await adminChat.sendMessage('/admin server set registration open');
      }
    } finally {
      await ctxAdmin.close();
      await ctxNewUser.close();
    }
  });
});
