import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'mode'): string {
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

async function setupUsersInChannel(
  browser: Browser,
  channel: string,
  prefixes: string[],
) {
  const users: TestUser[] = [];

  for (const prefix of prefixes) {
    const user = await newSignedInUser(browser, prefix);
    users.push(user);
    await user.chat.sendMessage(`/join ${channel}`);
    await user.chat.expectTabVisible(channel);
  }

  for (const user of users) {
    await user.chat.switchToTab(channel);
  }

  return users;
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Channel modes', () => {
  test('half-operators can voice/devoice users but cannot set protected channel modes (I4)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('halfop');
    const users = await setupUsersInChannel(browser, channel, [
      'own',
      'half',
      'reg',
    ]);
    const [owner, half, regular] = users;

    try {
      await owner.chat.sendMessage(`/mode +h ${half.nick}`);
      await owner.chat.expectNickRole(half.nick, 'half_operator');
      await half.chat.expectNickRole(half.nick, 'half_operator');

      await half.chat.sendMessage(`/voice ${regular.nick}`);
      await owner.chat.expectNickRole(regular.nick, 'voiced');
      await regular.chat.expectNickRole(regular.nick, 'voiced');

      await half.chat.sendMessage(`/devoice ${regular.nick}`);
      await owner.chat.expectNickRole(regular.nick, 'regular');
      await regular.chat.expectNickRole(regular.nick, 'regular');

      await half.chat.sendMessage('/mode +m');
      await half.chat.expectMessageVisible(
        'Insufficient privileges to set channel modes',
      );
    } finally {
      await closeUsers(users);
    }
  });

  test('moderated mode blocks regular users, allows voiced users, and restores on -m (I5)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('moderated');
    const users = await setupUsersInChannel(browser, channel, ['own', 'reg']);
    const [owner, regular] = users;
    const blockedMessage = `blocked-${Date.now()}`;
    const voicedMessage = `voiced-${Date.now()}`;
    const restoredMessage = `restored-${Date.now()}`;

    try {
      await owner.chat.sendMessage('/mode +m');

      await regular.chat.sendMessage(blockedMessage);
      await regular.chat.expectMessageVisible(
        'Channel is moderated (+m). You need voice (+v) to speak.',
      );
      await owner.chat.expectMessageHidden(blockedMessage);

      await owner.chat.sendMessage(`/voice ${regular.nick}`);
      await regular.chat.expectNickRole(regular.nick, 'voiced');

      await regular.chat.sendMessage(voicedMessage);
      await owner.chat.expectMessageVisible(voicedMessage);

      await owner.chat.sendMessage(`/devoice ${regular.nick}`);
      await regular.chat.expectNickRole(regular.nick, 'regular');
      await owner.chat.sendMessage('/mode -m');

      await regular.chat.sendMessage(restoredMessage);
      await owner.chat.expectMessageVisible(restoredMessage);
    } finally {
      await closeUsers(users);
    }
  });

  test('invite-only channels reject uninvited joins and allow invited users (I6)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('invite');
    const owner = await newSignedInUser(browser, 'own');
    const invited = await newSignedInUser(browser, 'inv');

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.sendMessage('/mode +i');

      await invited.chat.sendMessage(`/join ${channel}`);
      await invited.chat.expectMessageVisible('Channel is invite-only (+i)');
      await invited.chat.expectTabHidden(channel);

      await owner.chat.sendMessage(`/invite ${invited.nick}`);
      await owner.chat.expectMessageVisible(`* Inviting ${invited.nick} to ${channel}`);

      await invited.chat.acceptInvite(channel);
      await invited.chat.expectTabVisible(channel);
      await invited.chat.switchToTab(channel);
      await owner.chat.expectNickInList(invited.nick);
    } finally {
      await closeUsers([owner, invited]);
    }
  });

  test('key-protected channels reject bad keys and accept the correct key (I8)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('key');
    const owner = await newSignedInUser(browser, 'own');
    const guest = await newSignedInUser(browser, 'key');
    const key = `secret${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.sendMessage(`/mode +k ${key}`);

      await guest.chat.sendMessage(`/join ${channel} wrong`);
      await guest.chat.expectMessageVisible('Bad channel key (+k)');
      await guest.chat.expectTabHidden(channel);

      await guest.chat.sendMessage(`/join ${channel} ${key}`);
      await guest.chat.expectTabVisible(channel);
      await guest.chat.switchToTab(channel);
      await guest.chat.expectNickInList(owner.nick);
      await owner.chat.expectNickInList(guest.nick);
    } finally {
      await closeUsers([owner, guest]);
    }
  });

  test('channel limit mode blocks excess joins until removed (I9)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('limit');
    const owner = await newSignedInUser(browser, 'own');
    const guest = await newSignedInUser(browser, 'lim');

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.sendMessage('/mode +l 1');

      await guest.chat.sendMessage(`/join ${channel}`);
      await guest.chat.expectMessageVisible('Channel is full (+l)');
      await guest.chat.expectTabHidden(channel);

      await owner.chat.sendMessage('/mode -l');
      await guest.chat.sendMessage(`/join ${channel}`);
      await guest.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(guest.nick);
    } finally {
      await closeUsers([owner, guest]);
    }
  });

  test('topic lock blocks regular topic changes until removed (I10)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('topiclock');
    const users = await setupUsersInChannel(browser, channel, ['own', 'reg']);
    const [owner, regular] = users;
    const allowedTopic = `Allowed topic ${Date.now()}`;

    try {
      await owner.chat.sendMessage('/mode +t');

      await regular.chat.sendMessage('/topic blocked topic');
      await regular.chat.expectMessageVisible(
        'You must be a channel operator to change the topic',
      );

      await owner.chat.sendMessage('/mode -t');
      await regular.chat.sendMessage(`/topic ${allowedTopic}`);

      await owner.chat.expectMessageVisible(`changed the topic to: ${allowedTopic}`);
      await regular.chat.topicBar.getByText(allowedTopic).waitFor();
    } finally {
      await closeUsers(users);
    }
  });

  test('/slow throttles rapid joins until /slow 0 disables it (I14)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('slow');
    const owner = await newSignedInUser(browser, 'own');
    const guests: TestUser[] = [];

    try {
      for (let i = 0; i < 5; i += 1) {
        guests.push(await newSignedInUser(browser, `sl${i}`));
      }

      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.sendMessage('/slow 60');
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode +j`);

      for (const guest of guests.slice(0, 4)) {
        await guest.chat.sendMessage(`/join ${channel}`);
        await guest.chat.expectTabVisible(channel);
      }

      const throttledGuest = guests[4];
      await throttledGuest.chat.sendMessage(`/join ${channel}`);
      await throttledGuest.chat.expectMessageVisible(
        'Channel join throttle active, please try again shortly',
      );
      await throttledGuest.chat.expectTabHidden(channel);

      await owner.chat.sendMessage('/slow 0');
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode -j`);

      await throttledGuest.chat.sendMessage(`/join ${channel}`);
      await throttledGuest.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(throttledGuest.nick);
    } finally {
      await closeUsers([owner, ...guests]);
    }
  });
});
