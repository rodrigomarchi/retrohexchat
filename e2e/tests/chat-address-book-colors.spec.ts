import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: Page, prefix = 'abclr') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe('Address Book nick colors', () => {
  test('edit and remove immediately update existing and future chat rows (U13)', async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page);
    const stamp = Date.now();
    const existingMessage = `existing color row ${stamp}`;
    const futureMessage = `future color row ${stamp}`;
    const removedMessage = `removed color row ${stamp}`;

    await chat.sendMessage(existingMessage);
    await chat.expectMessageVisible(existingMessage);

    await chat.openAddressBookFromMenu();
    await chat.addAddressBookNickColor(nick, 4);
    await expect(chat.messageNickByText(existingMessage, nick)).toHaveClass(
      /irc-fg-4/,
    );

    await chat.editAddressBookNickColor(nick, 5);
    await expect(chat.messageNickByText(existingMessage, nick)).toHaveClass(
      /irc-fg-5/,
    );
    await expect(chat.messageNickByText(existingMessage, nick)).not.toHaveClass(
      /irc-fg-4/,
    );

    await chat.closeAddressBook();
    await chat.sendMessage(futureMessage);
    await chat.expectMessageVisible(futureMessage);
    await expect(chat.messageNickByText(futureMessage, nick)).toHaveClass(
      /irc-fg-5/,
    );

    await chat.openAddressBookFromMenu();
    await chat.removeAddressBookNickColor(nick);
    await expect(chat.messageNickByText(existingMessage, nick)).not.toHaveClass(
      /irc-fg-5/,
    );
    await expect(chat.messageNickByText(futureMessage, nick)).not.toHaveClass(
      /irc-fg-5/,
    );

    await chat.closeAddressBook();
    await chat.sendMessage(removedMessage);
    await chat.expectMessageVisible(removedMessage);
    await expect(chat.messageNickByText(removedMessage, nick)).not.toHaveClass(
      /irc-fg-5/,
    );
  });
});
