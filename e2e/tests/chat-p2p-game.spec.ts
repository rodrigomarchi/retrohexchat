import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
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
  prefix = 'p2pg',
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

test.describe('P2P game sessions', () => {
  test('/game creates a game lobby and starts a shared game shell (N7)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'p2pga');
    const bob = await newSignedInUser(browser, 'p2pgb');
    let aliceGame: GameSessionPage | undefined;
    let bobGame: GameSessionPage | undefined;

    try {
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

      aliceGame = await openGameSessionFromInvite(alice.page, aliceLink);
      bobGame = await openGameSessionFromInvite(bob.page, bobLink);

      await expect(bobGame.lobby).toContainText(
        `Waiting for ${alice.nick} to choose a game`,
        { timeout: 10_000 },
      );

      await aliceGame.selectGame('hex_pong');
      await expect(aliceGame.lobby).toContainText(
        `Waiting for ${bob.nick} to accept Hex Pong`,
        { timeout: 10_000 },
      );

      await bobGame.acceptGame('Hex Pong');

      await aliceGame.expectGameCanvas('hex_pong');
      await bobGame.expectGameCanvas('hex_pong');
    } finally {
      await aliceGame?.page.close().catch(() => {});
      await bobGame?.page.close().catch(() => {});
      await closeUsers([alice, bob]);
    }
  });
});
