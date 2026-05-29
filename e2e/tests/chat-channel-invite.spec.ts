import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'invite'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'e2e') {
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
  prefix = 'e2e',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);
  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Channel invites', () => {
  test('/invite auto joins invited channels without stealing the active tab (I7)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('autoinv');
    const owner = await newSignedInUser(browser, 'own');
    const invited = await newSignedInUser(browser, 'inv');
    const lobbyMarker = `lobby-focus-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.sendMessage('/mode +i');

      await invited.chat.switchToTab('#lobby');
      await invited.chat.sendMessage(lobbyMarker);
      await invited.chat.expectMessageVisible(lobbyMarker);
      await invited.chat.sendMessage('/invite auto');
      await invited.chat.expectMessageVisible('* Auto-join on invite: enabled');
      await invited.chat.expectTabSelected('#lobby');

      await owner.chat.sendMessage(`/invite ${invited.nick}`);

      await owner.chat.expectMessageVisible(`* Inviting ${invited.nick} to ${channel}`);
      await invited.chat.expectTabVisible(channel);
      await invited.chat.expectTabSelected('#lobby');
      await invited.chat.expectMessageVisible(
        `* You have been invited to ${channel} by ${owner.nick} (auto-joined)`,
      );
      await invited.chat.expectMessageVisible(lobbyMarker);
    } finally {
      await closeUsers([owner, invited]);
    }
  });
});
