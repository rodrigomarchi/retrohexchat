import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page, prefix = 'addr') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function submitDialogForm(form: Locator) {
  await form.getByRole('button', { name: 'OK' }).click();
}

test.describe('Address Book', () => {
  test('dialog manages contacts, notify entries, nick colors, and control entries (O16)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);
    const contactNick = uniqueNickname('ct');
    const notifyNick = uniqueNickname('nt');
    const colorNick = uniqueNickname('clr');
    const controlNick = uniqueNickname('ig');
    const contactNote = `contact-note-${Date.now()}`;
    const contactEdited = `contact-edited-${Date.now()}`;
    const notifyNote = `notify-note-${Date.now()}`;
    const notifyEdited = `notify-edited-${Date.now()}`;

    await chat.openAddressBookFromMenu();

    await chat.addressBookDialog.getByTestId('contact-add').click();
    let form = page.getByTestId('contact-add-form');
    await form.locator('#contact-add-nick').fill(contactNick);
    await form.locator('#contact-add-note').fill(contactNote);
    await submitDialogForm(form);
    await expect(chat.addressBookContactRow(contactNick)).toContainText(
      contactNote,
    );

    await chat.addressBookContactRow(contactNick).click();
    await chat.addressBookDialog.getByTestId('contact-edit').click();
    form = page.getByTestId('contact-edit-form');
    await form.locator('#contact-edit-note').fill(contactEdited);
    await submitDialogForm(form);
    await expect(chat.addressBookContactRow(contactNick)).toContainText(
      contactEdited,
    );

    await chat.addressBookContactRow(contactNick).click();
    await chat.addressBookDialog.getByTestId('contact-remove').click();
    await expect(chat.addressBookContactRow(contactNick)).toHaveCount(0);

    await chat.switchAddressBookToTab('Notify');
    await chat.addressBookDialog.getByTestId('ab-notify-add').click();
    form = page.getByTestId('ab-notify-add-form');
    await form.locator('#ab-notify-add-nick').fill(notifyNick);
    await form.locator('#ab-notify-add-note').fill(notifyNote);
    await submitDialogForm(form);
    await expect(chat.addressBookNotifyRow(notifyNick)).toContainText(
      notifyNote,
    );
    await expect(chat.addressBookNotifyRow(notifyNick)).toContainText('Offline');

    await chat.addressBookNotifyRow(notifyNick).click();
    await chat.addressBookDialog.getByTestId('ab-notify-edit').click();
    form = page.getByTestId('ab-notify-edit-form');
    await form.locator('#ab-notify-edit-note').fill(notifyEdited);
    await submitDialogForm(form);
    await expect(chat.addressBookNotifyRow(notifyNick)).toContainText(
      notifyEdited,
    );

    await chat.addressBookNotifyRow(notifyNick).click();
    await chat.addressBookDialog.getByTestId('ab-notify-remove').click();
    await expect(chat.addressBookNotifyRow(notifyNick)).toHaveCount(0);

    await chat.switchAddressBookToTab('Nick Colors');
    await chat.addressBookDialog.getByTestId('nick-color-add').click();
    form = page.getByTestId('nick-color-add-form');
    await form.locator('#nick-color-add-nick').fill(colorNick);
    await form.getByRole('button', { name: 'Color 4: Red' }).click();
    await submitDialogForm(form);
    await expect(chat.addressBookNickColorRow(colorNick)).toHaveAttribute(
      'data-color-index',
      '4',
    );

    await chat.addressBookNickColorRow(colorNick).click();
    await chat.addressBookDialog.getByTestId('nick-color-edit').click();
    form = page.getByTestId('nick-color-edit-form');
    await form.getByRole('button', { name: 'Color 5: Maroon' }).click();
    await submitDialogForm(form);
    await expect(chat.addressBookNickColorRow(colorNick)).toHaveAttribute(
      'data-color-index',
      '5',
    );

    await chat.addressBookNickColorRow(colorNick).click();
    await chat.addressBookDialog.getByTestId('nick-color-remove').click();
    await expect(chat.addressBookNickColorRow(colorNick)).toHaveCount(0);

    await chat.switchAddressBookToTab('Control');
    await chat.addressBookDialog.getByTestId('control-add').click();
    form = page.getByTestId('control-add-form');
    await form.locator('#control-add-nick').fill(controlNick);
    await form.locator('#control-add-type').selectOption('messages');
    await submitDialogForm(form);
    await expect(chat.addressBookControlRow(controlNick)).toContainText(
      'messages',
    );

    await chat.addressBookControlRow(controlNick).click();
    await chat.addressBookDialog.getByTestId('control-remove').click();
    await expect(chat.addressBookControlRow(controlNick)).toHaveCount(0);

    await chat.closeAddressBook();
  });

  test('custom nick color applies to message nick rendering (O17)', async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page, 'clrusr');
    const message = `custom color message ${Date.now()}`;

    await chat.openAddressBookFromMenu();
    await chat.switchAddressBookToTab('Nick Colors');

    await chat.addressBookDialog.getByTestId('nick-color-add').click();
    const form = page.getByTestId('nick-color-add-form');
    await form.locator('#nick-color-add-nick').fill(nick);
    await form.getByRole('button', { name: 'Color 4: Red' }).click();
    await submitDialogForm(form);
    await expect(chat.addressBookNickColorRow(nick)).toHaveAttribute(
      'data-color-index',
      '4',
    );

    await chat.closeAddressBook();
    await chat.sendMessage(message);
    await chat.expectMessageVisible(message);

    await expect(chat.messageNickByText(message, nick)).toHaveClass(/irc-fg-4/);
  });
});
