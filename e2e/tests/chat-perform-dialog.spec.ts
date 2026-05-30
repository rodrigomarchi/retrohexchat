import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'pfdlg'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: Page,
  prefix = 'pfdlg',
  password = 'pass12345',
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, nick, password };
}

async function reconnectRegisteredUser(
  page: Page,
  chat: ChatPage,
  nick: string,
  password: string,
) {
  const connect = new ConnectPage(page);

  await chat.disconnect();
  await connect.open();
  await connect.enterNickname(nick);
  await connect.authenticateWithPassword(password);
  await chat.waitUntilConnected();
}

test.describe('Perform dialog', () => {
  test('edits, moves, and toggles perform commands with reconnect behavior (U6)', async ({
    page,
  }) => {
    const { chat, nick, password } = await signedInUser(page);
    const firstChannel = uniqueChannel('pfold');
    const editedChannel = uniqueChannel('pfedit');
    const movedChannel = uniqueChannel('pfmove');
    const firstCommand = `/join ${firstChannel}`;
    const editedCommand = `/join ${editedChannel}`;
    const movedCommand = `/join ${movedChannel}`;

    await chat.openPerformDialogFromMenu();
    await chat.addPerformCommand(firstCommand);
    await chat.addPerformCommand(movedCommand);

    await chat.editPerformCommand(firstCommand, editedCommand);
    await chat.movePerformCommandUp(movedCommand);
    await expect(chat.performEnabledCheckbox()).toBeChecked();
    await chat.performEnabledCheckbox().click();
    await expect(chat.performEnabledCheckbox()).not.toBeChecked();
    await chat.closePerformDialog();

    await chat.sendMessage('/clear');
    await chat.sendMessage('/perform list');
    await chat.expectMessageVisible(`0: ${movedCommand}`);
    await chat.expectMessageVisible(`1: ${editedCommand}`);
    await chat.expectMessageHidden(firstCommand);

    await page.waitForTimeout(500);
    await reconnectRegisteredUser(page, chat, nick, password);
    await chat.expectTabHidden(movedChannel);
    await chat.expectTabHidden(editedChannel);

    await chat.openPerformDialogFromMenu();
    await expect(chat.performEnabledCheckbox()).not.toBeChecked();
    await chat.performEnabledCheckbox().click();
    await expect(chat.performEnabledCheckbox()).toBeChecked();
    await chat.closePerformDialog();

    await page.waitForTimeout(500);
    await reconnectRegisteredUser(page, chat, nick, password);
    await chat.expectTabVisible(movedChannel);
    await chat.expectTabVisible(editedChannel);
    await chat.expectTabSelected('#lobby');

    await chat.switchToStatusTab();
    await chat.expectStatusMessageVisible(`* Performing: ${movedCommand}`);
    await chat.expectStatusMessageVisible(`* Performing: ${editedCommand}`);
  });

  test('autojoin tab adds, edits, removes, and affects reconnect behavior (U7)', async ({
    page,
  }) => {
    const { chat, nick, password } = await signedInUser(page, 'ajdlg');
    const keyedChannel = uniqueChannel('ajkey');
    const removedChannel = uniqueChannel('ajrm');
    const editedKey = `edited-${Date.now()}`;

    await chat.openPerformDialogFromMenu();
    await chat.switchPerformDialogToAutojoinTab();
    await chat.addAutojoinEntry(keyedChannel, 'first-key');
    await expect(chat.autojoinRow(keyedChannel)).toContainText('***');
    await chat.addAutojoinEntry(removedChannel);

    await chat.editAutojoinKey(keyedChannel, editedKey);
    await chat.autojoinRow(keyedChannel).click();
    await chat.performDialog.getByRole('button', { name: 'Edit' }).click();
    await expect(chat.autojoinEditDialog.locator('#autojoin-edit-key')).toHaveValue(
      editedKey,
    );
    await chat.autojoinEditDialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(chat.autojoinEditDialog).toBeHidden();

    await chat.removeAutojoinEntry(removedChannel);
    await chat.closePerformDialog();

    await chat.sendMessage('/clear');
    await chat.sendMessage('/autojoin list');
    await chat.expectMessageVisible(`${keyedChannel} (key: ****)`);
    await chat.expectMessageHidden(removedChannel);

    await page.waitForTimeout(500);
    await reconnectRegisteredUser(page, chat, nick, password);
    await chat.expectTabVisible(keyedChannel);
    await chat.expectTabHidden(removedChannel);
    await chat.expectTabSelected('#lobby');

    await chat.switchToStatusTab();
    await chat.expectStatusMessageVisible(`* Auto-joining ${keyedChannel}...`);

    await chat.openPerformDialogFromMenu();
    await chat.switchPerformDialogToAutojoinTab();
    await chat.removeAutojoinEntry(keyedChannel);
    await chat.closePerformDialog();

    await chat.switchToTab('#lobby');
    await chat.sendMessage('/clear');
    await chat.sendMessage('/autojoin list');
    await chat.expectMessageVisible('Your auto-join list is empty');
  });
});
