import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'adc'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'adc',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe.serial('Admin channel commands', () => {
  test('/admin channel create/info/list/banlist/delete over unique channel (M9)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const channel = uniqueChannel('adccrud');

    try {
      await admin.chat.sendMessage(`/admin channel create ${channel}`);
      await admin.chat.expectMessageVisible(
        `Channel ${channel} created and registered.`,
      );

      await admin.chat.sendMessage(`/admin channel info ${channel}`);
      await admin.chat.expectMessageVisible(`*** Channel: ${channel}`);
      await admin.chat.expectMessageVisible('Registered: yes');

      await admin.chat.sendMessage('/clear');
      await admin.chat.sendMessage(`/admin channel list --search ${channel}`);
      await admin.chat.expectMessageVisible('*** Channel List (1) ***');
      await admin.chat.expectMessageVisible(`${channel} (0 members)`);

      await admin.chat.sendMessage(`/admin channel banlist ${channel}`);
      await admin.chat.expectMessageVisible(`*** No bans in ${channel}.`);

      await admin.chat.sendMessage(`/admin channel delete ${channel}`);
      await admin.chat.expectMessageVisible(`Channel ${channel} has been deleted.`);
    } finally {
      await admin.chat.sendMessage(`/admin channel delete ${channel}`);
      await closeUsers([admin]);
    }
  });

  test('/admin channel purge #room --from bob removes only bob visible history (M10)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const bob = await newSignedInUser(browser, 'adcb');
    const alice = await newSignedInUser(browser, 'adca');
    const channel = uniqueChannel('adcpurge');
    const bobText = `purge-bob-${Date.now()}`;
    const aliceText = `purge-alice-${Date.now()}`;

    try {
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.switchToTab(channel);

      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await alice.chat.expectNickInList(bob.nick);

      await bob.chat.sendMessage(bobText);
      await alice.chat.expectMessageVisible(bobText);

      await alice.chat.sendMessage(aliceText);
      await alice.chat.expectMessageVisible(aliceText);

      await admin.chat.sendMessage(
        `/admin channel purge ${channel} --from ${bob.nick}`,
      );
      await admin.chat.expectMessageVisible(
        `Purged 1 messages from ${bob.nick} in ${channel}.`,
      );

      await alice.chat.expectMessageHidden(bobText);
      await alice.chat.expectMessageVisible(aliceText);
    } finally {
      await admin.chat.sendMessage(`/admin channel delete ${channel}`);
      await closeUsers([admin, bob, alice]);
    }
  });
});
