import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'mod'): string {
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
  const owner = await newSignedInUser(browser, 'own');
  const regular = await newSignedInUser(browser, 'reg');

  await owner.chat.sendMessage(`/join ${channel}`);
  await owner.chat.expectTabVisible(channel);

  await regular.chat.sendMessage(`/join ${channel}`);
  await regular.chat.expectTabVisible(channel);

  await owner.chat.expectNickInList(regular.nick);
  await regular.chat.expectNickInList(owner.nick);

  return { owner, regular };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Channel moderation', () => {
  test('/ban removes and blocks a user until /unban allows rejoin (I11)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('ban');
    const reason = `ban-${Date.now()}`;
    const { owner, regular } = await setupTwoUsersInChannel(browser, channel);

    try {
      await owner.chat.sendMessage(`/ban ${regular.nick} ${reason}`);

      await owner.chat.expectMessageVisible(
        `${regular.nick} was banned by ${owner.nick} (${reason})`,
      );
      await owner.chat.expectNickNotInList(regular.nick);
      await regular.chat.expectTabHidden(channel);
      await regular.chat.dismissKickDialog();

      await regular.chat.switchToTab('#lobby');
      await regular.chat.sendMessage(`/join ${channel}`);
      await regular.chat.expectMessageVisible(`You are banned from ${channel}`);
      await regular.chat.expectTabHidden(channel);

      await owner.chat.sendMessage(`/unban ${regular.nick}`);
      await owner.chat.expectMessageVisible(
        `${regular.nick} was unbanned by ${owner.nick}`,
      );

      await regular.chat.sendMessage(`/join ${channel}`);
      await regular.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(regular.nick);
    } finally {
      await closeUsers([owner, regular]);
    }
  });

  test('/kick removes the target channel tab and broadcasts the reason (I12)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('kick');
    const reason = `kick-${Date.now()}`;
    const { owner, regular } = await setupTwoUsersInChannel(browser, channel);

    try {
      await owner.chat.sendMessage(`/kick ${regular.nick} ${reason}`);

      await owner.chat.expectMessageVisible(
        `${regular.nick} was kicked by ${owner.nick} (${reason})`,
      );
      await owner.chat.expectNickNotInList(regular.nick);
      await regular.chat.expectTabHidden(channel);
      await regular.chat.dismissKickDialog();
    } finally {
      await closeUsers([owner, regular]);
    }
  });

  test('/mute blocks channel messages and /unmute restores sending (I13)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('mute');
    const { owner, regular } = await setupTwoUsersInChannel(browser, channel);
    const mutedMessage = `muted-${Date.now()}`;
    const restoredMessage = `unmuted-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/mute ${regular.nick}`);
      await owner.chat.expectMessageVisible(
        `${regular.nick} has been muted in ${channel}.`,
      );
      await regular.chat.expectMessageVisible(
        `${regular.nick} has been muted in ${channel}.`,
      );

      await regular.chat.sendMessage(mutedMessage);
      await regular.chat.expectMessageVisible('You are muted in this channel');
      await owner.chat.expectMessageHidden(mutedMessage);

      await owner.chat.sendMessage(`/unmute ${regular.nick}`);
      await owner.chat.expectMessageVisible(
        `${regular.nick} has been unmuted in ${channel}.`,
      );

      await regular.chat.sendMessage(restoredMessage);
      await owner.chat.expectMessageVisible(restoredMessage);
    } finally {
      await closeUsers([owner, regular]);
    }
  });
});
