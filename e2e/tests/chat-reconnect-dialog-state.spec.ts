import { Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueAlias(prefix = 'aa2'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signedInUser(page: Page, prefix = 'aa2') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe('Reconnect dialog state', () => {
  test('browser offline/online preserves unsaved Alias Editor draft and can save after reconnect (AA2)', async ({
    context,
    page,
  }) => {
    test.setTimeout(45_000);

    const { chat } = await signedInUser(page, 'aa2');
    const alias = uniqueAlias();
    const marker = `aa2-alias-${Date.now()}`;
    const expansion = `/me ${marker}`;

    await chat.openAliasEditorFromMenu();
    await chat.startAliasAdd();
    await chat.fillAliasDraft(alias, expansion);

    try {
      await context.setOffline(true);
      await expect(chat.connectionBanner).toHaveClass(
        /connection-banner--visible/,
        { timeout: 5_000 },
      );
      await expect(chat.aliasDialog).toBeVisible();
      await expect(chat.aliasEditForm).toBeVisible();
      await expect(chat.aliasEditForm.getByTestId('alias-name-input')).toHaveValue(
        alias,
      );
      await expect(
        chat.aliasEditForm.getByTestId('alias-expansion-input'),
      ).toHaveValue(expansion);

      await context.setOffline(false);
      await expect(chat.connectionBanner).toContainText('Reconectado', {
        timeout: 15_000,
      });
      await chat.waitUntilConnected();

      await expect(chat.aliasDialog).toBeVisible();
      await expect(chat.aliasEditForm).toBeVisible();
      await expect(chat.aliasEditForm.getByTestId('alias-name-input')).toHaveValue(
        alias,
      );
      await expect(
        chat.aliasEditForm.getByTestId('alias-expansion-input'),
      ).toHaveValue(expansion);

      await chat.saveAliasDraft();
      await expect(chat.aliasEditForm).toBeHidden();
      await expect(chat.aliasRow(alias)).toContainText(expansion);

      await chat.closeAliasEditor();
      await chat.sendMessage(`/${alias}`);
      await chat.expectMessageVisible(marker);
    } finally {
      await context.setOffline(false).catch(() => {});
    }
  });
});
