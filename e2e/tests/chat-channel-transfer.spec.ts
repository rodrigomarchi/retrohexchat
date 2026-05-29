import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'transfer'): string {
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

test.describe('Channel transfer', () => {
  test('/transfer changes ownership and demotes the previous owner (I17)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('xfer');
    const owner = await newSignedInUser(browser, 'own');
    const successor = await newSignedInUser(browser, 'new');

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await successor.chat.sendMessage(`/join ${channel}`);

      await owner.chat.expectNickRole(owner.nick, 'owner');
      await owner.chat.expectNickRole(successor.nick, 'regular');

      await owner.chat.sendMessage(`/transfer ${successor.nick}`);

      await owner.chat.expectMessageVisible(
        `Channel ownership transferred to ${successor.nick}.`,
      );
      await owner.chat.expectNickRole(successor.nick, 'owner');
      await owner.chat.expectNickRole(owner.nick, 'operator');
      await successor.chat.expectNickRole(successor.nick, 'owner');
      await successor.chat.expectNickRole(owner.nick, 'operator');

      await owner.chat.sendMessage(`/transfer ${owner.nick}`);
      await owner.chat.expectMessageVisible(
        'You must be the channel owner to use this command',
      );
    } finally {
      await closeUsers([owner, successor]);
    }
  });
});
