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

function uniqueChannel(prefix = 'ann'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'ann',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
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
  const page: Page = await ctx.newPage();
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

test.describe('Announcements', () => {
  test('/announce broadcasts to connected users and bypasses ignore filters (M18)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const alice = await newSignedInUser(browser, 'anna');
    const channel = uniqueChannel('ann');
    const hiddenText = `ignored-admin-message-${Date.now()}`;
    const announcement = `global-announcement-${Date.now()}`;

    try {
      await admin.chat.sendMessage(`/join ${channel}`);
      await admin.chat.expectTabVisible(channel);
      await admin.chat.switchToTab(channel);

      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await alice.chat.expectNickInList(ADMIN_NICK);

      await alice.chat.sendMessage(`/ignore ${ADMIN_NICK} all`);
      await alice.chat.expectMessageVisible(
        `* ${ADMIN_NICK} is now ignored (all)`,
      );

      await admin.chat.sendMessage(hiddenText);
      await alice.chat.expectMessageHidden(hiddenText);

      await admin.chat.sendMessage(`/announce ${announcement}`);
      await admin.chat.expectMessageVisible('Announcement sent to all users.');
      await admin.chat.expectMessageVisible(announcement);
      await alice.chat.expectMessageVisible(announcement);
    } finally {
      await closeUsers([admin, alice]);
    }
  });
});
