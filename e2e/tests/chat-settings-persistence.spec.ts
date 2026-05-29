import { Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'persist'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

function uniqueAlias(prefix = 'persist'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signedInUser(
  page: Page,
  prefix = 'persist',
  password = 'pass12345',
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, nick, password };
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

async function submitDialogForm(form: Locator) {
  await form.getByRole('button', { name: 'OK' }).click();
}

async function becomeGuest(page: Page, chat: ChatPage, guestNick: string) {
  await chat.sendMessage(`/nick ${guestNick}`);
  await expect(page.getByTestId('nick-change-dialog')).toBeVisible();
  await page.getByTestId('nick-change-confirm').click();
  await chat.waitUntilConnected();
  await expect(chat.nicklistItem(guestNick)).toBeVisible();
}

test.describe('Chat settings persistence', () => {
  test('registered user settings persist across reconnect (P6)', async ({
    page,
  }) => {
    const { chat, nick, password } = await signedInUser(page, 'prst');
    const alias = uniqueAlias('pa');
    const aliasText = `persist-alias-${Date.now()}`;
    const performAway = `persist-away-${Date.now()}`;
    const autojoinChannel = uniqueChannel('paj');
    const ignoredNick = uniqueNickname('pig');
    const notifyNick = uniqueNickname('pnt');
    const notifyNote = `persist-note-${Date.now().toString(36)}`;
    const colorMessage = `persist-color-${Date.now()}`;

    await chat.sendMessage(`/alias add ${alias} /me ${aliasText}`);
    await chat.expectMessageVisible(`* Alias /${alias} created`);

    await chat.sendMessage(`/perform add /away ${performAway}`);
    await chat.expectMessageVisible(`* Added to perform list: /away ${performAway}`);

    await chat.sendMessage(`/autojoin add ${autojoinChannel}`);
    await chat.expectMessageVisible(`* Added to auto-join list: ${autojoinChannel}`);

    await chat.sendMessage(`/ignore ${ignoredNick} messages`);
    await chat.expectMessageVisible(`* ${ignoredNick} is now ignored (messages)`);

    await chat.switchToStatusTab();
    await chat.sendMessage(`/notify add ${notifyNick} ${notifyNote}`);
    await chat.expectStatusMessageVisible(`Added ${notifyNick} to notify list`);
    await chat.switchToTab('#lobby');

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

    await page.waitForTimeout(750);
    await reconnectRegisteredUser(page, chat, nick, password);

    await chat.switchToStatusTab();

    await chat.sendMessage('/alias list');
    await chat.expectStatusMessageVisible(`/${alias}`);
    await chat.expectStatusMessageVisible(`/me ${aliasText}`);

    await chat.sendMessage('/perform list');
    await chat.expectStatusMessageVisible(`0: /away ${performAway}`);

    await chat.sendMessage('/autojoin list');
    await chat.expectStatusMessageVisible(autojoinChannel);

    await chat.sendMessage('/ignore');
    await chat.expectStatusMessageVisible(`${ignoredNick} [messages]`);

    await chat.sendMessage('/notify list');
    await chat.expectStatusMessageVisible(`${notifyNick} [offline] - ${notifyNote}`);

    await chat.switchToTab('#lobby');
    await chat.sendMessage(colorMessage);
    await chat.expectMessageVisible(colorMessage);
    await expect(chat.messageNickByText(colorMessage, nick)).toHaveClass(
      /irc-fg-4/,
    );
  });

  test('guest settings are session-only after reload (P7)', async ({ page }) => {
    const { chat } = await signedInUser(page, 'pgst');
    const guestNick = uniqueNickname('pgst');
    const alias = uniqueAlias('ga');
    const aliasText = `guest-alias-${Date.now()}`;
    const performAway = `guest-away-${Date.now()}`;
    const autojoinChannel = uniqueChannel('gaj');
    const ignoredNick = uniqueNickname('gig');
    const notifyNick = uniqueNickname('gnt');
    const notifyNote = `guest-note-${Date.now().toString(36)}`;
    const colorMessage = `guest-color-${Date.now()}`;

    await becomeGuest(page, chat, guestNick);

    await chat.sendMessage(`/alias add ${alias} /me ${aliasText}`);
    await chat.expectMessageVisible(`* Alias /${alias} created`);

    await chat.sendMessage(`/perform add /away ${performAway}`);
    await chat.expectMessageVisible(`* Added to perform list: /away ${performAway}`);

    await chat.sendMessage(`/autojoin add ${autojoinChannel}`);
    await chat.expectMessageVisible(`* Added to auto-join list: ${autojoinChannel}`);

    await chat.sendMessage(`/ignore ${ignoredNick} messages`);
    await chat.expectMessageVisible(`* ${ignoredNick} is now ignored (messages)`);

    await chat.switchToStatusTab();
    await chat.sendMessage(`/notify add ${notifyNick} ${notifyNote}`);
    await chat.expectStatusMessageVisible(`Added ${notifyNick} to notify list`);
    await chat.switchToTab('#lobby');

    await chat.openAddressBookFromMenu();
    await chat.switchAddressBookToTab('Nick Colors');
    await chat.addressBookDialog.getByTestId('nick-color-add').click();
    const form = page.getByTestId('nick-color-add-form');
    await form.locator('#nick-color-add-nick').fill(guestNick);
    await form.getByRole('button', { name: 'Color 4: Red' }).click();
    await submitDialogForm(form);
    await expect(chat.addressBookNickColorRow(guestNick)).toHaveAttribute(
      'data-color-index',
      '4',
    );
    await chat.closeAddressBook();

    await page.reload();
    await chat.waitUntilConnected();

    await chat.switchToStatusTab();

    await chat.sendMessage('/alias list');
    await chat.expectStatusMessageVisible('Your alias list is empty');

    await chat.sendMessage('/perform list');
    await chat.expectStatusMessageVisible('Your perform list is empty');

    await chat.sendMessage('/autojoin list');
    await chat.expectStatusMessageVisible('Your auto-join list is empty');

    await chat.sendMessage('/ignore');
    await chat.expectStatusMessageVisible('Your ignore list is empty');

    await chat.sendMessage('/notify list');
    await chat.expectStatusMessageVisible('Your notify list is empty');

    await chat.switchToTab('#lobby');
    await chat.sendMessage(colorMessage);
    await chat.expectMessageVisible(colorMessage);
    await expect(
      chat.messageNickByText(colorMessage, guestNick),
    ).not.toHaveClass(/irc-fg-4/);
  });
});
