import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  connect: ConnectPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
  password: string;
};

function uniqueChannel(prefix = 'adm'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'adm',
  password = 'pass12345',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password };
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

  return { chat, connect, ctx, page, nick, password };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe.serial('Admin user commands', () => {
  test('/admin user list/info/banlist display targeted rows (M4)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'adml');
    const bannedNick = uniqueNickname('banl');
    const banReason = `banlist-${Date.now()}`;

    try {
      await admin.chat.sendMessage(`/admin user list --search ${target.nick}`);
      await admin.chat.expectMessageVisible('*** User List (1 results) ***');
      await admin.chat.expectMessageVisible(`${target.nick} [registered]`);

      await admin.chat.sendMessage(`/admin user info ${target.nick}`);
      await admin.chat.expectMessageVisible(`*** User: ${target.nick}`);
      await admin.chat.expectMessageVisible('Registered:');
      await admin.chat.expectMessageVisible('Online: true');

      await admin.chat.sendMessage(
        `/admin user ban ${bannedNick} --reason ${banReason}`,
      );
      await admin.chat.expectMessageVisible(
        `${bannedNick} has been server-banned permanently.`,
      );

      await admin.chat.sendMessage('/clear');
      await admin.chat.sendMessage(`/admin user banlist --search ${bannedNick}`);
      await admin.chat.expectMessageVisible('*** Server Ban List (1) ***');
      await admin.chat.expectMessageVisible(bannedNick);
      await admin.chat.expectMessageVisible(banReason);
    } finally {
      await admin.chat.sendMessage(`/admin user unban ${bannedNick}`);
      await closeUsers([admin, target]);
    }
  });

  test('/admin user kick force-disconnects target; target can reconnect (M5)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const victim = await newSignedInUser(browser, 'admk', 'kickpass123');
    const reason = `admin-kick-${Date.now()}`;

    try {
      await admin.chat.sendMessage(
        `/admin user kick ${victim.nick} --reason ${reason}`,
      );
      await admin.chat.expectMessageVisible(
        `${victim.nick} has been kicked from the server.`,
      );

      await expect(victim.page).toHaveURL(/\/connect\?reason=/);
      await expect(victim.page.getByTestId('session-alert')).toContainText(
        reason,
      );

      await victim.connect.open();
      await victim.connect.enterNickname(victim.nick);
      await victim.connect.authenticateWithPassword(victim.password);
      await victim.chat.waitUntilConnected();
    } finally {
      await closeUsers([admin, victim]);
    }
  });

  test('/admin user mute blocks sends; unmute restores sends (M6)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'admm');
    const channel = uniqueChannel('mute');
    const blockedText = `muted-send-${Date.now()}`;
    const restoredText = `unmuted-send-${Date.now()}`;

    try {
      await target.chat.sendMessage(`/join ${channel}`);
      await target.chat.expectTabVisible(channel);
      await target.chat.switchToTab(channel);

      await admin.chat.sendMessage(`/admin user mute ${target.nick}`);
      await admin.chat.expectMessageVisible(
        `${target.nick} has been muted permanently.`,
      );
      await target.chat.expectMessageVisible(
        'You have been muted by an administrator',
      );

      await target.chat.sendMessage(blockedText);
      await target.chat.expectMessageVisible(
        'You are muted by an administrator',
      );
      await target.chat.expectMessageHidden(blockedText);

      await admin.chat.sendMessage(`/admin user unmute ${target.nick}`);
      await admin.chat.expectMessageVisible(`${target.nick} has been unmuted.`);
      await target.chat.expectMessageVisible(
        'You have been unmuted by an administrator.',
      );

      await target.chat.sendMessage(restoredText);
      await target.chat.expectMessageVisible(restoredText);
    } finally {
      await admin.chat.sendMessage(`/admin user unmute ${target.nick}`);
      await closeUsers([admin, target]);
    }
  });

  test('/admin user rename updates target session and channel nicklists (M7)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, 'admr');
    const observer = await newSignedInUser(browser, 'admo');
    const channel = uniqueChannel('rename');
    const newNick = uniqueNickname('admrn');

    try {
      await target.chat.sendMessage(`/join ${channel}`);
      await target.chat.expectTabVisible(channel);

      await observer.chat.sendMessage(`/join ${channel}`);
      await observer.chat.expectTabVisible(channel);
      await observer.chat.switchToTab(channel);
      await observer.chat.expectNickInList(target.nick);

      await admin.chat.sendMessage(
        `/admin user rename ${target.nick} ${newNick}`,
      );
      await admin.chat.expectMessageVisible(
        `${target.nick} has been renamed to ${newNick}.`,
      );

      await target.chat.expectMessageVisible(
        `Your nickname was changed to ${newNick} by an administrator.`,
      );
      await observer.chat.expectNickInList(newNick);
      await observer.chat.expectNickNotInList(target.nick);
    } finally {
      await closeUsers([admin, target, observer]);
    }
  });

  test('/admin user role validates root-admin and non-admin restrictions (M8)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const regular = await newSignedInUser(browser, 'admu');
    const target = await newSignedInUser(browser, 'admt');

    try {
      await admin.chat.sendMessage(`/admin user role ${target.nick} admin`);
      await admin.chat.expectMessageVisible(
        'Only root admins can promote users to admin',
      );

      await regular.chat.sendMessage(
        `/admin user role ${target.nick} server_operator`,
      );
      await regular.chat.expectMessageVisible(
        'You must be a server administrator to use this command',
      );
    } finally {
      await closeUsers([admin, regular, target]);
    }
  });
});
