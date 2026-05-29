import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'e2e') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'e2e',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Notify list commands', () => {
  test('/notify add tracks online and offline buddy status changes (J15)', async ({
    browser,
  }) => {
    const users: TestUser[] = [];
    const alice = await newSignedInUser(browser, 'ntfa');
    const bobNick = uniqueNickname('ntfb');
    users.push(alice);

    try {
      await alice.chat.switchToStatusTab();
      await alice.chat.sendMessage(`/notify add ${bobNick}`);
      await alice.chat.expectStatusMessageVisible(
        `Added ${bobNick} to notify list`,
      );

      const bobCtx = await browser.newContext();
      const bobPage = await bobCtx.newPage();
      const bobConnect = new ConnectPage(bobPage);
      const bobChat = new ChatPage(bobPage);
      users.push({ chat: bobChat, ctx: bobCtx, nick: bobNick });

      await bobConnect.open();
      await bobConnect.enterNickname(bobNick);
      await bobConnect.registerWithPassword('pass12345');
      await bobChat.waitUntilConnected();

      await alice.chat.expectStatusMessageVisible(
        `* ${bobNick} is now online`,
        15_000,
      );

      await bobChat.disconnect();

      await alice.chat.expectStatusMessageVisible(
        `* ${bobNick} has gone offline`,
        15_000,
      );
    } finally {
      await closeUsers(users);
    }
  });

  test('/notify edit/list/remove updates command output and dialogs (J16)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'ntfc');
    const targetNick = uniqueNickname('ntfd');
    const firstNote = `first-note-${Date.now().toString(36)}`;
    const editedNote = `edited-note-${Date.now().toString(36)}`;

    try {
      await alice.chat.switchToStatusTab();

      await alice.chat.sendMessage(`/notify add ${targetNick} ${firstNote}`);
      await alice.chat.expectStatusMessageVisible(
        `Added ${targetNick} to notify list`,
      );

      await alice.chat.sendMessage('/notify list');
      await alice.chat.expectStatusMessageVisible(
        `${targetNick} [offline] - ${firstNote}`,
      );

      await alice.chat.sendMessage(`/notify edit ${targetNick} ${editedNote}`);
      await alice.chat.expectStatusMessageVisible(
        `Updated note for ${targetNick}`,
      );

      await alice.chat.sendMessage('/notify list');
      await alice.chat.expectStatusMessageVisible(
        `${targetNick} [offline] - ${editedNote}`,
      );

      await alice.chat.sendMessage('/notify');
      await expect(alice.chat.notifyListDialog).toBeVisible();
      await expect(alice.chat.notifyListRow(targetNick)).toContainText(
        targetNick,
      );
      await expect(alice.chat.notifyListRow(targetNick)).toContainText(
        'Offline',
      );
      await alice.chat.closeNotifyList();

      await alice.chat.openAddressBookFromMenu();
      await alice.chat.switchAddressBookToNotifyTab();
      await expect(alice.chat.addressBookNotifyRow(targetNick)).toContainText(
        editedNote,
      );
      await expect(alice.chat.addressBookNotifyRow(targetNick)).toContainText(
        'Offline',
      );
      await alice.chat.closeAddressBook();

      await alice.chat.sendMessage(`/notify remove ${targetNick}`);
      await alice.chat.expectStatusMessageVisible(
        `Removed ${targetNick} from notify list`,
      );

      await alice.chat.sendMessage('/clear');
      await alice.chat.sendMessage('/notify list');
      await alice.chat.expectStatusMessageVisible('Your notify list is empty');

      await alice.chat.openAddressBookFromMenu();
      await alice.chat.switchAddressBookToNotifyTab();
      await expect(alice.chat.addressBookNotifyRow(targetNick)).toHaveCount(0);
      await alice.chat.closeAddressBook();
    } finally {
      await closeUsers([alice]);
    }
  });
});
