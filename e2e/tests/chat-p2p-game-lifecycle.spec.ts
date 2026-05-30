import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';
import {
  GameSessionPage,
  openGameSessionFromInvite,
} from '../pages/GameSessionPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = 'p2pgl',
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

  return { chat, ctx, page, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function openGameLobbies(alice: TestUser, bob: TestUser) {
  await alice.chat.sendMessage(`/game ${bob.nick}`);
  await alice.chat.expectTabVisible(bob.nick);
  await alice.chat.expectTabSelected(bob.nick);
  await alice.chat.expectMessageVisible(
    `Game invite sent to ${bob.nick}. Waiting for response...`,
  );
  await alice.chat.expectMessageVisible('Game session started');

  const aliceLink = alice.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(aliceLink).toHaveAttribute('href', /^\/game\/[A-Za-z0-9_-]+$/);
  const inviteHref = await aliceLink.getAttribute('href');

  await bob.chat.expectTabVisible(alice.nick);
  await bob.chat.expectTabSelected('#lobby');
  await bob.chat.switchToTab(alice.nick);

  const bobLink = bob.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(bobLink).toHaveAttribute('href', inviteHref || '');

  const aliceGame = await openGameSessionFromInvite(alice.page, aliceLink);
  const bobGame = await openGameSessionFromInvite(bob.page, bobLink);

  await expect(aliceGame.gameButton('hex_pong')).toBeVisible({ timeout: 10_000 });
  await expect(bobGame.lobby).toContainText(
    `Waiting for ${alice.nick} to choose a game`,
    { timeout: 10_000 },
  );

  return { aliceGame, bobGame };
}

test.describe('P2P game lifecycle', () => {
  test('leaving a game invite closes the leaving popup and updates the peer lobby without stealing chat focus (Z10)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z10la');
    const bob = await newSignedInUser(browser, 'z10lb');
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ aliceGame, bobGame } = await openGameLobbies(alice, bob));

      await bob.chat.switchToTab('#lobby');
      await alice.chat.expectTabSelected(bob.nick);
      await bob.chat.expectTabSelected('#lobby');

      const bobClosed = bobGame.page.waitForEvent('close');
      await bobGame.leave();
      await bobClosed;

      await expect(aliceGame.sessionEnded).toBeVisible({ timeout: 10_000 });
      await expect(aliceGame.page.getByText('Session closed by user.')).toBeVisible();

      await alice.chat.expectTabSelected(bob.nick);
      await bob.chat.expectTabSelected('#lobby');
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });

  test('declining a selected game clears the request and returns both peers to lobby state (Z10)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'z10da');
    const bob = await newSignedInUser(browser, 'z10db');
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
      ({ aliceGame, bobGame } = await openGameLobbies(alice, bob));

      await bob.chat.switchToTab('#lobby');

      await aliceGame.selectGame('hex_pong');
      await expect(aliceGame.lobby).toContainText(
        `Waiting for ${bob.nick} to accept Hex Pong`,
        { timeout: 10_000 },
      );

      await bobGame.declineGame('Hex Pong');

      await expect(aliceGame.gameButton('hex_pong')).toBeVisible({
        timeout: 10_000,
      });
      await expect(aliceGame.lobby).toContainText('Choose a game:', {
        timeout: 10_000,
      });
      await expect(bobGame.lobby).toContainText(
        `Waiting for ${alice.nick} to choose a game`,
        { timeout: 10_000 },
      );
      await expect(aliceGame.canvas).toHaveCount(0);
      await expect(bobGame.canvas).toHaveCount(0);
      await bob.chat.expectTabSelected('#lobby');
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
