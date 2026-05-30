import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueAlias(prefix = 'alias'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signedInUser(page: Page, prefix = 'aldg') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe('Alias dialog edge cases', () => {
  test('validates aliases, warns about recursion, and discards canceled drafts (U10)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'aldg');
    const stamp = Date.now();
    const alias = uniqueAlias('base');
    const originalText = `alias-original-${stamp}`;
    const editedText = `alias-edited-${stamp}`;
    const loopAlias = uniqueAlias('loop');
    const cancelAlias = uniqueAlias('drop');

    await chat.openAliasEditorFromMenu();
    await chat.addAliasFromDialog(alias, `/me ${originalText}`);

    await chat.startAliasAdd();
    await chat.fillAliasDraft(alias.toUpperCase(), `/me duplicate-${stamp}`);
    await chat.saveAliasDraft();
    await chat.expectAliasError(`Alias /${alias.toUpperCase()} already exists`);

    await chat.fillAliasDraft(uniqueAlias('empty'), '');
    await chat.saveAliasDraft();
    await chat.expectAliasError('Expansion is required');

    await chat.fillAliasDraft(loopAlias, `/${loopAlias}`);
    await chat.saveAliasDraft();
    await expect(chat.aliasEditForm).toBeHidden();
    await expect(chat.aliasRow(loopAlias)).toContainText(`/${loopAlias}`);
    await expect(chat.aliasWarning).toContainText('recursion limit');

    await chat.startAliasAdd();
    await chat.fillAliasDraft(cancelAlias, `/me canceled-${stamp}`);
    await chat.cancelAliasDraft();
    await expect(chat.aliasRow(cancelAlias)).toHaveCount(0);

    await chat.aliasRow(alias).click();
    await chat.aliasDialog.getByRole('button', { name: 'Edit' }).click();
    await expect(chat.aliasEditForm).toBeVisible();
    await chat.aliasEditForm
      .getByTestId('alias-expansion-input')
      .fill(`/me ${editedText}`);
    await chat.cancelAliasDraft();
    await expect(chat.aliasRow(alias)).toContainText(`/me ${originalText}`);
    await expect(chat.aliasRow(alias)).not.toContainText(editedText);

    await chat.closeAliasEditor();
    await chat.sendMessage(`/${alias}`);
    await chat.expectMessageVisible(originalText);
  });
});
