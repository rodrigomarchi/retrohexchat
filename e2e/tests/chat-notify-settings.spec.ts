import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'ntfs') {
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
  prefix = 'ntfs',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function newSignedInUserWithNick(
  browser: Browser,
  nick: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function reconnectRegisteredUser(user: TestUser, password: string) {
  const connect = new ConnectPage(user.chat.page);

  await user.chat.disconnect();
  await connect.open();
  await connect.enterNickname(user.nick);
  await connect.authenticateWithPassword(password);
  await user.chat.waitUntilConnected();
}

test.describe('Notify List settings', () => {
  test.setTimeout(60_000);

  test('auto-add PM and auto-WHOIS settings affect later PM and online events (U11)', async ({
    browser,
  }) => {
    const users: TestUser[] = [];
    const alice = await newSignedInUser(browser, 'ntfa');
    const bob = await newSignedInUser(browser, 'ntfb');
    const carol = await newSignedInUser(browser, 'ntfc');
    const daveNick = uniqueNickname('ntfd');
    const stamp = Date.now();
    users.push(alice, bob, carol);

    try {
      await alice.chat.switchToStatusTab();

      await alice.chat.openNotifyListFromCommand();
      await expect(alice.chat.notifyAutoAddPmToggle).toBeChecked();
      await alice.chat.setNotifyAutoAddPm(false);
      await alice.chat.closeNotifyList();

      await bob.chat.sendMessage(`/msg ${alice.nick} no-auto-add-${stamp}`);
      await alice.chat.expectTabVisible(bob.nick);

      await alice.chat.openNotifyListFromCommand();
      await expect(alice.chat.notifyListRow(bob.nick)).toHaveCount(0);
      await alice.chat.setNotifyAutoAddPm(true);
      await alice.chat.closeNotifyList();

      await carol.chat.sendMessage(`/msg ${alice.nick} auto-add-${stamp}`);
      await alice.chat.expectTabVisible(carol.nick);

      await alice.chat.openNotifyListFromCommand();
      await expect(alice.chat.notifyListRow(carol.nick)).toContainText('Online');
      await expect(alice.chat.notifyListRow(bob.nick)).toHaveCount(0);
      await alice.chat.setNotifyAutoWhois(true);
      await alice.chat.closeNotifyList();

      await alice.chat.sendMessage(`/notify add ${daveNick}`);
      await alice.chat.expectStatusMessageVisible(
        `Added ${daveNick} to notify list`,
      );

      const dave = await newSignedInUserWithNick(browser, daveNick);
      users.push(dave);

      await alice.chat.expectStatusMessageVisible(
        `* ${daveNick} is now online`,
        15_000,
      );
      await alice.chat.expectStatusMessageVisible(
        `[Auto-Whois] ${daveNick}:`,
        15_000,
      );
    } finally {
      await closeUsers(users);
    }
  });

  test('auto-WHOIS emits details when a watched user comes online (W9)', async ({
    browser,
  }) => {
    const users: TestUser[] = [];
    const alice = await newSignedInUser(browser, 'w9a');
    const watchedNick = uniqueNickname('w9b');
    users.push(alice);

    try {
      await alice.chat.switchToStatusTab();
      await alice.chat.openNotifyListFromCommand();
      await alice.chat.setNotifyAutoWhois(true);
      await alice.chat.closeNotifyList();

      await alice.chat.sendMessage(`/notify add ${watchedNick}`);
      await alice.chat.expectStatusMessageVisible(
        `Added ${watchedNick} to notify list`,
      );

      const watched = await newSignedInUserWithNick(browser, watchedNick);
      users.push(watched);

      await alice.chat.expectStatusMessageVisible(
        `* ${watchedNick} is now online`,
        15_000,
      );
      await alice.chat.expectStatusMessageVisible(
        `[Auto-Whois] ${watchedNick}:`,
        15_000,
      );
      await alice.chat.expectStatusMessageVisible(
        'Registered: yes (identified)',
        15_000,
      );
    } finally {
      await closeUsers(users);
    }
  });

  test('auto-add-PM adds PM partners and persists for registered users (W10)', async ({
    browser,
  }) => {
    const password = 'pass12345';
    const users: TestUser[] = [];
    const alice = await newSignedInUser(browser, 'w10a');
    const bob = await newSignedInUser(browser, 'w10b');
    const stamp = Date.now();
    users.push(alice, bob);

    try {
      await alice.chat.switchToStatusTab();
      await alice.chat.openNotifyListFromCommand();
      await alice.chat.setNotifyAutoAddPm(true);
      await alice.chat.closeNotifyList();

      await bob.chat.sendMessage(`/msg ${alice.nick} auto-add-persist-${stamp}`);
      await alice.chat.expectTabVisible(bob.nick);

      await alice.chat.openNotifyListFromCommand();
      await expect(alice.chat.notifyListRow(bob.nick)).toContainText('Online');
      await alice.chat.closeNotifyList();

      await alice.chat.page.waitForTimeout(750);
      await reconnectRegisteredUser(alice, password);

      await alice.chat.openNotifyListFromCommand();
      await expect(alice.chat.notifyListRow(bob.nick)).toContainText('Online');
    } finally {
      await closeUsers(users);
    }
  });
});
