import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'abct'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'abct') {
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
  prefix = 'abct',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'abca');
  const bob = await newSignedInUser(browser, 'abcb');

  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);
  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);
  await alice.chat.expectNickInList(bob.nick);

  return { alice, bob };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Address Book contacts', () => {
  test('contact notes appear in hover card and whois output (U12)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('abct');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const note = `contact-context-note-${Date.now()}`;
    const message = `contact-note-message-${Date.now()}`;

    try {
      await alice.chat.openAddressBookFromMenu();
      await alice.chat.addAddressBookContact(bob.nick, note);
      await alice.chat.closeAddressBook();

      await bob.chat.sendMessage(message);
      await alice.chat.expectMessageVisible(message);

      await alice.chat.messageNickByText(message, bob.nick).hover();
      const card = alice.chat.hoverCard(bob.nick);
      await expect(card).toBeVisible();
      await expect(card).toContainText('Contact');
      await expect(card).toContainText('Note');
      await expect(card).toContainText(note);

      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await alice.chat.expectMessageVisible(`----- Whois: ${bob.nick} -----`);
      await alice.chat.expectMessageVisible(`Contact note: ${note}`);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
