import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'p2p',
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

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectStatusCommand(chat: ChatPage, command: string, expected: string) {
  await chat.switchToTab('#lobby');
  await chat.sendMessage(command);
  await chat.switchToStatusTab();
  await chat.expectStatusMessageVisible(expected);
}

test.describe('P2P command errors', () => {
  test('unidentified user cannot start P2P, call, file, or game sessions (N1)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'p2pa');
    const bob = await newSignedInUser(browser, 'p2pb');
    const guestNick = uniqueNickname('p2pg');

    try {
      await alice.chat.sendMessage(`/nick ${guestNick}`);
      await alice.chat.confirmNickChange();
      await alice.chat.expectNickInList(guestNick);

      await expectStatusCommand(
        alice.chat,
        `/p2p ${bob.nick}`,
        'You must be identified to use /p2p.',
      );
      await expectStatusCommand(
        alice.chat,
        `/call ${bob.nick}`,
        'You must be identified to use /p2p.',
      );
      await expectStatusCommand(
        alice.chat,
        `/sendfile ${bob.nick}`,
        'You must be identified to use /p2p.',
      );
      await expectStatusCommand(
        alice.chat,
        `/game ${bob.nick}`,
        'You must be identified to use /game.',
      );
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('registered identified user cannot target self for P2P flows (N2)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'p2ps');

    try {
      await alice.chat.sendMessage(`/p2p ${alice.nick}`);
      await alice.chat.expectMessageVisible(
        'You cannot start a P2P session with yourself.',
      );

      await alice.chat.sendMessage(`/call ${alice.nick}`);
      await alice.chat.expectMessageVisible(
        'You cannot start a P2P session with yourself.',
      );

      await alice.chat.sendMessage(`/sendfile ${alice.nick}`);
      await alice.chat.expectMessageVisible(
        'You cannot start a P2P session with yourself.',
      );

      await alice.chat.sendMessage(`/game ${alice.nick}`);
      await alice.chat.expectMessageVisible(
        'You cannot start a game session with yourself.',
      );
    } finally {
      await closeUsers([alice]);
    }
  });

  test('registered identified user sees not-registered errors for missing target (N3)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'p2pm');
    const missingNick = uniqueNickname('p2px');

    try {
      await alice.chat.sendMessage(`/p2p ${missingNick}`);
      await alice.chat.expectMessageVisible(`User '${missingNick}' is not registered.`);

      await alice.chat.sendMessage(`/call ${missingNick}`);
      await alice.chat.expectMessageVisible(`User '${missingNick}' is not registered.`);

      await alice.chat.sendMessage(`/sendfile ${missingNick}`);
      await alice.chat.expectMessageVisible(`User '${missingNick}' is not registered.`);

      await alice.chat.sendMessage(`/game ${missingNick}`);
      await alice.chat.expectMessageVisible(`User '${missingNick}' is not registered.`);
    } finally {
      await closeUsers([alice]);
    }
  });
});
