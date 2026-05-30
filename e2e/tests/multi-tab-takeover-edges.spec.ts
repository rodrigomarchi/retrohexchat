import { expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

test.describe('Multi-tab takeover edges', () => {
  test('same nick takeover closes source with unsaved draft/dialog and keeps new session usable (AA4)', async ({
    browser,
  }) => {
    const ctxA = await browser.newContext();
    const ctxB = await browser.newContext();
    const pageA = await ctxA.newPage();
    const pageB = await ctxB.newPage();
    const nick = uniqueNickname('aa4');
    const password = 'testpass123';
    const draft = `aa4 unsent draft ${Date.now()}`;
    const alias = `aa4${Math.random().toString(36).slice(2, 7)}`;
    const expansion = `/me aa4 unsaved alias ${Date.now()}`;
    const message = `aa4 new session alive ${Date.now()}`;

    try {
      const connectA = new ConnectPage(pageA);
      const chatA = new ChatPage(pageA);
      await connectA.open();
      await connectA.enterNickname(nick);
      await connectA.registerWithPassword(password);
      await chatA.waitUntilConnected();

      await chatA.chatInput.fill(draft);
      await chatA.openAliasEditorFromMenu();
      await chatA.startAliasAdd();
      await chatA.fillAliasDraft(alias, expansion);
      await expect(chatA.aliasDialog).toBeVisible();
      await expect(chatA.aliasEditForm.getByTestId('alias-name-input')).toHaveValue(
        alias,
      );

      const connectB = new ConnectPage(pageB);
      const chatB = new ChatPage(pageB);
      await connectB.open();
      await connectB.enterNickname(nick);
      await connectB.authenticateWithPassword(password);
      await chatB.waitUntilConnected();

      await expect(pageA).toHaveURL(/\/connect\?reason=/);
      await expect(pageA.getByTestId('session-alert')).toContainText(
        'Session ended',
      );
      await expect(pageA.getByTestId('session-alert')).toContainText(
        'logged in from another window',
      );
      await expect(connectA.nicknameInput).toBeVisible();
      await expect(pageA.getByTestId('alias-dialog')).toHaveCount(0);
      await expect(pageA.getByTestId('chat-input-field')).toHaveCount(0);

      await chatB.expectTabSelected('#lobby');
      await expect(chatB.aliasDialog).toBeHidden();
      await expect(chatB.chatInput).toHaveValue('');
      await chatB.sendMessage(message);
      await chatB.expectMessageVisible(message);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
