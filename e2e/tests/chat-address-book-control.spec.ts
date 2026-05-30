import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import {
  AddressBookControlType,
  ChatPage,
} from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'abctl'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'abctl') {
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
  prefix = 'abctl',
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
  await bob.chat.expectNickInList(alice.nick);

  return { alice, bob };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function setControlType(
  chat: ChatPage,
  nick: string,
  type: AddressBookControlType,
) {
  await chat.openAddressBookFromMenu();
  await chat.addAddressBookControlEntry(nick, type);
  await chat.closeAddressBook();
  await chat.sendMessage('/ignore');
  await chat.expectMessageVisible(`${nick} [${type}]`);
}

test.describe('Address Book control entries', () => {
  test('Control tab ignore types filter like /ignore entries (U14)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const channel = uniqueChannel('abctl');
    const inviteChannel = uniqueChannel('abinv');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const stamp = Date.now();

    try {
      await setControlType(alice.chat, bob.nick, 'messages');
      const hiddenChannel = `control-messages-hidden-${stamp}`;
      const visiblePm = `control-messages-visible-pm-${stamp}`;
      await bob.chat.sendMessage(hiddenChannel);
      await alice.chat.expectMessageHidden(hiddenChannel);
      await bob.chat.sendMessage(`/msg ${alice.nick} ${visiblePm}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageVisible(visiblePm);

      await alice.chat.switchToTab(channel);
      await setControlType(alice.chat, bob.nick, 'pms');
      const visibleChannel = `control-pms-visible-channel-${stamp}`;
      const hiddenPm = `control-pms-hidden-pm-${stamp}`;
      await bob.chat.sendMessage(visibleChannel);
      await alice.chat.expectMessageVisible(visibleChannel);
      await bob.chat.sendMessage(`/msg ${alice.nick} ${hiddenPm}`);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageHidden(hiddenPm);

      await alice.chat.switchToTab(channel);
      await setControlType(alice.chat, bob.nick, 'actions');
      const hiddenAction = `control-actions-hidden-${stamp}`;
      const visibleAfterAction = `control-actions-visible-${stamp}`;
      await bob.chat.sendMessage(`/me ${hiddenAction}`);
      await alice.chat.expectMessageHidden(hiddenAction);
      await bob.chat.sendMessage(visibleAfterAction);
      await alice.chat.expectMessageVisible(visibleAfterAction);

      await setControlType(alice.chat, bob.nick, 'notices');
      const hiddenNotice = `control-notices-hidden-${stamp}`;
      const visibleAfterNotice = `control-notices-visible-${stamp}`;
      await bob.chat.sendMessage(`/notice ${alice.nick} ${hiddenNotice}`);
      await alice.chat.expectMessageHidden(hiddenNotice);
      await bob.chat.sendMessage(visibleAfterNotice);
      await alice.chat.expectMessageVisible(visibleAfterNotice);

      await setControlType(alice.chat, bob.nick, 'invites');
      await bob.chat.sendMessage(`/join ${inviteChannel}`);
      await bob.chat.expectTabVisible(inviteChannel);
      await bob.chat.sendMessage('/mode +i');
      await bob.chat.sendMessage(`/invite ${alice.nick}`);
      await bob.chat.expectMessageVisible(
        `* Inviting ${alice.nick} to ${inviteChannel}`,
      );
      await alice.chat.expectInviteHidden(inviteChannel);

      await bob.chat.switchToTab(channel);
      await setControlType(alice.chat, bob.nick, 'all');
      const hiddenAllChannel = `control-all-hidden-channel-${stamp}`;
      const hiddenAllPm = `control-all-hidden-pm-${stamp}`;
      await bob.chat.sendMessage(hiddenAllChannel);
      await alice.chat.expectMessageHidden(hiddenAllChannel);
      await bob.chat.sendMessage(`/msg ${alice.nick} ${hiddenAllPm}`);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageHidden(hiddenAllPm);

      await alice.chat.switchToTab(channel);
      await alice.chat.openAddressBookFromMenu();
      await alice.chat.removeAddressBookControlEntry(bob.nick);
      await alice.chat.closeAddressBook();

      const restoredMessage = `control-restored-${stamp}`;
      await bob.chat.sendMessage(restoredMessage);
      await alice.chat.expectMessageVisible(restoredMessage);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
