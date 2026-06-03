import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('shell'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

test.describe('Reconnect shell state', () => {
  test('reconnect disables destructive menus but keeps Help accessible (T12)', async ({
    context,
    page,
  }) => {
    test.setTimeout(45_000);

    const chat = await signedInUser(page);
    const draft = `offline shell draft ${Date.now()}`;

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

      await expect(chat.fileMenuTrigger).toHaveAttribute(
        'data-disabled',
        'true',
      );
      await expect(chat.viewMenuTrigger).toHaveAttribute(
        'data-disabled',
        'true',
      );
      await expect(chat.toolsMenuTrigger).toHaveAttribute(
        'data-disabled',
        'true',
      );
      await expect(chat.helpMenuTrigger).toHaveAttribute(
        'data-disabled',
        'false',
      );

      await chat.fileMenuTrigger.click({ force: true });
      await expect(chat.disconnectMenuItem).toBeHidden();

      await chat.viewMenuTrigger.click({ force: true });
      await expect(chat.findMenuItem).toBeHidden();

      await chat.toolsMenuTrigger.click({ force: true });
      await expect(chat.addressBookMenuItem).toBeHidden();

      await chat.helpMenuTrigger.click();
      await expect(chat.aboutMenuItem).toBeVisible();
      await chat.aboutMenuItem.click();
      await expect(chat.aboutDialog).toBeVisible();
      await chat.aboutOkButton.click();
      await expect(chat.aboutDialog).toBeHidden();
      await expect(chat.chatInput).toHaveValue(draft);

      await context.setOffline(false);
      await expect(chat.connectionBanner).toContainText(/Reconectado|Reconnected!/, {
        timeout: 15_000,
      });
      await page.waitForFunction(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        () => !!(window as any).liveSocket?.isConnected?.(),
        { timeout: 10_000 },
      );

      await expect(chat.fileMenuTrigger).toHaveAttribute(
        'data-disabled',
        'false',
      );
      await expect(chat.viewMenuTrigger).toHaveAttribute(
        'data-disabled',
        'false',
      );
      await expect(chat.toolsMenuTrigger).toHaveAttribute(
        'data-disabled',
        'false',
      );
      await expect(chat.chatInput).toBeEnabled();
      await expect(chat.chatInput).toHaveValue(draft);
      await expect(chat.chatSendButton).toBeEnabled();
    } finally {
      await context.setOffline(false);
    }
  });
});
