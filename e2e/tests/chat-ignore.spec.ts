import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'ignore'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

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

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'igna');
  const bob = await newSignedInUser(browser, 'ignb');

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

test.describe('Ignore commands', () => {
  test('/ignore bob all hides channel messages, actions, PMs, notices, and invites (J5)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('all');
    const inviteChannel = uniqueChannel('allinv');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const channelText = `ignore-all-message-${Date.now()}`;
    const actionText = `ignore-all-action-${Date.now()}`;
    const pmText = `ignore-all-pm-${Date.now()}`;
    const noticeText = `ignore-all-notice-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/ignore ${bob.nick} all`);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} is now ignored (all)`,
      );

      await bob.chat.sendMessage(channelText);
      await alice.chat.expectMessageHidden(channelText);

      await bob.chat.sendMessage(`/me ${actionText}`);
      await alice.chat.expectMessageHidden(actionText);

      await bob.chat.sendMessage(`/msg ${alice.nick} ${pmText}`);
      await alice.chat.expectTabHidden(bob.nick);

      await bob.chat.sendMessage(`/notice ${alice.nick} ${noticeText}`);
      await alice.chat.expectMessageHidden(noticeText);

      await bob.chat.sendMessage(`/join ${inviteChannel}`);
      await bob.chat.sendMessage('/mode +i');
      await bob.chat.sendMessage(`/invite ${alice.nick}`);
      await bob.chat.expectMessageVisible(
        `* Inviting ${alice.nick} to ${inviteChannel}`,
      );
      await alice.chat.expectInviteHidden(inviteChannel);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('type-specific ignore separates channel messages from PMs (J6)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('types');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const hiddenChannelText = `ignore-messages-channel-${Date.now()}`;
    const visiblePmText = `ignore-messages-pm-${Date.now()}`;
    const visibleChannelText = `ignore-pms-channel-${Date.now()}`;
    const hiddenPmText = `ignore-pms-pm-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/ignore ${bob.nick} messages`);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} is now ignored (messages)`,
      );

      await bob.chat.sendMessage(hiddenChannelText);
      await alice.chat.expectMessageHidden(hiddenChannelText);

      await bob.chat.sendMessage(`/msg ${alice.nick} ${visiblePmText}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageVisible(visiblePmText);

      await alice.chat.sendMessage(`/ignore ${bob.nick} pms`);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} ignore updated to: pms`,
      );

      await alice.chat.switchToTab(channel);
      await bob.chat.sendMessage(visibleChannelText);
      await alice.chat.expectMessageVisible(visibleChannelText);

      await bob.chat.sendMessage(`/msg ${alice.nick} ${hiddenPmText}`);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageHidden(hiddenPmText);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('/ignore lists entries and /unignore restores visibility (J7)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('list');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const hiddenText = `ignore-list-hidden-${Date.now()}`;
    const restoredText = `ignore-list-restored-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/ignore ${bob.nick} messages`);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} is now ignored (messages)`,
      );

      await alice.chat.sendMessage('/ignore');
      await alice.chat.expectMessageVisible(`${bob.nick} [messages]`);

      await bob.chat.sendMessage(hiddenText);
      await alice.chat.expectMessageHidden(hiddenText);

      await alice.chat.sendMessage(`/unignore ${bob.nick}`);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} is no longer ignored`,
      );

      await bob.chat.sendMessage(restoredText);
      await alice.chat.expectMessageVisible(restoredText);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('/ignore with duration expires and restores visibility (J9)', async ({
    browser,
  }) => {
    test.setTimeout(100_000);

    const channel = uniqueChannel('expiry');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const hiddenText = `ignore-expiry-hidden-${Date.now()}`;
    const restoredText = `ignore-expiry-restored-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/ignore ${bob.nick} messages 1m`);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} is now ignored (messages)`,
      );

      await bob.chat.sendMessage(hiddenText);
      await alice.chat.expectMessageHidden(hiddenText);

      await alice.chat.expectMessageVisible(
        `* ${bob.nick} is no longer ignored (timer expired)`,
        70_000,
      );

      await bob.chat.sendMessage(restoredText);
      await alice.chat.expectMessageVisible(restoredText);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('/ignore <ownnick> shows a self-ignore error (J8)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'selfign');

    try {
      await alice.chat.sendMessage(`/ignore ${alice.nick}`);
      await alice.chat.expectMessageVisible('You cannot ignore yourself');
    } finally {
      await closeUsers([alice]);
    }
  });
});
