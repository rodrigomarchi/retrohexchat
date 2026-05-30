import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'ardlg'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname('ardlg'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return chat;
}

test.describe('Autorespond dialog', () => {
  test('add, edit, toggle, delete, and field validation mirror slash output (U8)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const channel = uniqueChannel();
    const initialText = `dialog-autorespond-initial-${Date.now()}`;
    const editedText = `dialog-autorespond-edited-${Date.now()}`;
    const initialCommand = `/notice $nick ${initialText}`;
    const editedCommand = `/notice $nick ${editedText}`;

    await chat.openAutorespondDialogFromMenu();

    await chat.startAutorespondAdd();
    await chat.fillAutorespondDraft('not-a-channel', initialCommand);
    await chat.saveAutorespondDraft();
    await expect(chat.autorespondEditForm).toContainText(
      'Channel filter must start with #',
    );

    await chat.fillAutorespondDraft(channel, '');
    await chat.saveAutorespondDraft();
    await expect(chat.autorespondEditForm).toContainText('Command is required');

    await chat.fillAutorespondDraft(channel, `${initialCommand} && /quit`);
    await chat.saveAutorespondDraft();
    await expect(chat.autorespondEditForm).toContainText(
      'Command must not contain chaining',
    );

    await chat.fillAutorespondDraft(channel, initialCommand);
    await chat.saveAutorespondDraft();
    await expect(chat.autorespondEditForm).toBeHidden();
    await expect(chat.autorespondRuleRow(initialCommand)).toContainText(channel);

    await chat.autorespondRuleToggle(initialCommand).click();
    await expect(chat.autorespondRuleToggle(initialCommand)).not.toBeChecked();
    await chat.autorespondDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.autorespondDialog).toBeHidden();

    await chat.sendMessage('/clear');
    await chat.sendMessage('/autorespond list');
    await chat.expectMessageVisible(`0: [OFF] on_join ${channel}`);
    await chat.expectMessageVisible(initialText);

    await chat.openAutorespondDialogFromMenu();
    await chat.editAutorespondRule(initialCommand, editedCommand);
    await chat.autorespondRuleToggle(editedCommand).click();
    await expect(chat.autorespondRuleToggle(editedCommand)).toBeChecked();
    await chat.autorespondDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.autorespondDialog).toBeHidden();

    await chat.sendMessage('/clear');
    await chat.sendMessage('/autorespond list');
    await chat.expectMessageVisible(`0: [ON] on_join ${channel}`);
    await chat.expectMessageVisible(editedText);

    await chat.openAutorespondDialogFromMenu();
    await chat.removeAutorespondRule(editedCommand);
    await chat.autorespondDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.autorespondDialog).toBeHidden();

    await chat.sendMessage('/clear');
    await chat.sendMessage('/autorespond list');
    await chat.expectMessageVisible('No auto-respond rules configured.');
  });
});
