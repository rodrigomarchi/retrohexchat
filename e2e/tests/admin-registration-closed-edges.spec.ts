import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';
import { resetRegistrationOpen } from '../helpers/e2eState';

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

async function newSignedInUser(
  browser: Browser,
  prefix = 'aa6',
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

async function setRegistration(admin: TestUser, value: 'open' | 'closed') {
  await admin.chat.sendMessage(`/admin server set registration ${value}`);
  await admin.chat.expectMessageVisible(
    `Server setting 'registration' set to '${value}'.`,
  );
}

test.describe.serial('Registration closed edges', () => {
  test.afterAll(() => {
    resetRegistrationOpen();
  });

  test('closed registration blocks new users but existing registered users can authenticate (AA6)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    let existing: TestUser | undefined;
    let blockedCtx: BrowserContext | undefined;
    let blockedConnect: ConnectPage | undefined;
    const blockedNick = uniqueNickname('aa6new');

    try {
      await setRegistration(admin, 'open');
      existing = await newSignedInUser(browser, 'aa6ex', 'existpass123');
      blockedCtx = await browser.newContext();
      const blockedPage = await blockedCtx.newPage();
      blockedConnect = new ConnectPage(blockedPage);
      await existing.chat.disconnect();

      await setRegistration(admin, 'closed');

      await blockedConnect.open();
      await blockedConnect.enterNickname(blockedNick);
      await expect(blockedConnect.registerPasswordInput).toBeVisible();
      await blockedConnect.registerPasswordInput.fill('newpass123');
      await blockedConnect.registerPasswordConfirmInput.fill('newpass123');
      await blockedConnect.registerButton.click();
      await expect(blockedConnect.registerError).toContainText(
        'Registration is currently closed',
      );

      await existing.connect.signIn(existing.nick, existing.password);
      await existing.chat.waitUntilConnected();
    } finally {
      await setRegistration(admin, 'open').catch(() => {});
      await blockedCtx?.close();
      await closeUsers([admin, existing].filter(Boolean) as TestUser[]);
    }
  });

  test('closed registration does not let nickname takeover bypass password auth (AA7)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    let source: TestUser | undefined;
    let challengerCtx: BrowserContext | undefined;
    let challengerConnect: ConnectPage | undefined;
    let challengerChat: ChatPage | undefined;
    const sourceMarker = `aa7 source alive ${Date.now()}`;

    try {
      await setRegistration(admin, 'open');
      source = await newSignedInUser(browser, 'aa7own', 'ownerpass123');
      challengerCtx = await browser.newContext();
      const challengerPage = await challengerCtx.newPage();
      challengerConnect = new ConnectPage(challengerPage);
      challengerChat = new ChatPage(challengerPage);
      await setRegistration(admin, 'closed');

      await challengerConnect.open();
      await challengerConnect.enterNickname(source.nick);
      await expect(challengerConnect.authPasswordInput).toBeVisible();
      await expect(challengerConnect.registerPasswordInput).toHaveCount(0);

      await challengerConnect.authPasswordInput.fill('wrong-password');
      await challengerConnect.authButton.click();
      await expect(challengerConnect.authError).toContainText(
        'Incorrect password',
      );
      await expect(source.page).toHaveURL(/\/chat(\?.*)?$/);
      await source.chat.sendMessage(sourceMarker);
      await source.chat.expectMessageVisible(sourceMarker);

      await challengerConnect.authPasswordInput.fill(source.password);
      await challengerConnect.authButton.click();
      await challengerChat.waitUntilConnected();

      await expect(source.page).toHaveURL(/\/connect\?reason=/);
      await expect(source.page.getByTestId('session-alert')).toContainText(
        'logged in from another window',
      );
    } finally {
      await setRegistration(admin, 'open').catch(() => {});
      await challengerCtx?.close();
      await closeUsers([admin, source].filter(Boolean) as TestUser[]);
    }
  });
});
