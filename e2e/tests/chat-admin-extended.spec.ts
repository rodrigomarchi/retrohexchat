import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'adm') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
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

test.describe.serial('Admin server commands', () => {
  test('non-admin /admin server info shows permission error (M1)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'admna');

    await chat.sendMessage('/admin server info');
    await chat.expectMessageVisible(
      'You must be a server administrator to use this command',
    );
  });

  test('admin /admin server info/get/settings displays server data (M2)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await admin.chat.sendMessage('/admin server info');
      await admin.chat.expectMessageVisible('Users online:');
      await admin.chat.expectMessageVisible('Active channels:');
      await admin.chat.expectMessageVisible('Registration:');
      await admin.chat.expectMessageVisible('BEAM uptime:');

      await admin.chat.sendMessage('/admin server set registration open');
      await admin.chat.expectMessageVisible(
        "Server setting 'registration' set to 'open'.",
      );

      await admin.chat.sendMessage('/clear');
      await admin.chat.sendMessage('/admin server get registration');
      await admin.chat.expectMessageVisible("*** registration = 'open'");

      await admin.chat.sendMessage('/admin server settings');
      await admin.chat.expectMessageVisible('*** Server Settings ***');
      await admin.chat.expectMessageVisible("registration = 'open'");
    } finally {
      await closeUsers([admin]);
    }
  });

  test('admin server setting validation rejects invalid values and restores safe defaults (M3)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await admin.chat.sendMessage('/admin server set registration locked');
      await admin.chat.expectMessageVisible(
        "registration must be 'open' or 'closed'",
      );

      await admin.chat.sendMessage('/admin server set max_channels 0');
      await admin.chat.expectMessageVisible(
        'max_channels must be a positive integer',
      );

      await admin.chat.sendMessage('/admin server set max_channels nope');
      await admin.chat.expectMessageVisible(
        'max_channels must be a positive integer',
      );
    } finally {
      await admin.chat.sendMessage('/admin server set registration open');
      await admin.chat.sendMessage('/admin server set max_channels 10');
      await closeUsers([admin]);
    }
  });
});
