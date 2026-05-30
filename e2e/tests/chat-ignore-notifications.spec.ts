import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'ignotify'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'ignotify') {
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
  prefix = 'ignotify',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectTitleDoesNotFlash(page: Page, stableTitle: string) {
  await page.waitForTimeout(1_700);
  await expect(page).toHaveTitle(stableTitle);
}

test.describe('Ignore notification suppression', () => {
  test('ignored PM sender does not create unread, typing indicator, or title flash (V10)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'v10a');
    const bob = await newSignedInUser(browser, 'v10b');
    const ignoredPm = `ignored-pm-notify-${Date.now()}`;
    const ignoredTyping = `ignored-typing-${Date.now()}`;

    try {
      await bob.chat.sendMessage(`/ignore ${alice.nick} pms`);
      await bob.chat.expectMessageVisible(
        `* ${alice.nick} is now ignored (pms)`,
      );
      await bob.chat.expectTabSelected('#lobby');

      const stableTitle = await bob.chat.page.title();
      await alice.chat.sendMessage(`/msg ${bob.nick} ${ignoredPm}`);

      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabHidden(alice.nick);
      await expect(bob.chat.pmConversationItem(alice.nick)).toHaveCount(0);
      await expectTitleDoesNotFlash(bob.chat.page, stableTitle);

      await bob.chat.sendMessage(`/query ${alice.nick}`);
      await bob.chat.expectTabSelected(alice.nick);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectTabSelected(bob.nick);
      await alice.chat.chatInput.fill(ignoredTyping);

      await bob.chat.page.waitForTimeout(500);
      await expect(bob.chat.typingIndicator).toHaveCount(0);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('ignored inviter does not open invite UI or steal focus (V11)', async ({
    browser,
  }) => {
    const inviteChannel = uniqueChannel('ignoredinv');
    const alice = await newSignedInUser(browser, 'v11a');
    const bob = await newSignedInUser(browser, 'v11b');

    try {
      await alice.chat.sendMessage(`/ignore ${bob.nick} invites`);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} is now ignored (invites)`,
      );
      await alice.chat.expectTabSelected('#lobby');

      await bob.chat.sendMessage(`/join ${inviteChannel}`);
      await bob.chat.expectTabVisible(inviteChannel);
      await bob.chat.sendMessage('/mode +i');
      await bob.chat.sendMessage(`/invite ${alice.nick}`);
      await bob.chat.expectMessageVisible(
        `* Inviting ${alice.nick} to ${inviteChannel}`,
      );

      await alice.chat.expectTabSelected('#lobby');
      await alice.chat.expectTabHidden(inviteChannel);
      await alice.chat.expectInviteHidden(inviteChannel);
      await alice.chat.page.waitForTimeout(500);
      await alice.chat.expectTabSelected('#lobby');
      await expect(alice.chat.inviteJoinButton(inviteChannel)).toHaveCount(0);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
