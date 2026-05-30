import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'ccex'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'ccex') {
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
  prefix = 'ccex',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Channel Central exceptions', () => {
  test('ban and invite exception add/remove flows affect join behavior (U15)', async ({
    browser,
  }) => {
    test.setTimeout(90_000);

    const channel = uniqueChannel('ccex');
    const owner = await newSignedInUser(browser, 'cown');
    const banned = await newSignedInUser(browser, 'cban');
    const invited = await newSignedInUser(browser, 'cinv');

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.addChannelCentralBan(banned.nick);
      await owner.chat.closeChannelCentral();

      await banned.chat.sendMessage(`/join ${channel}`);
      await banned.chat.expectMessageVisible(`You are banned from ${channel}`);
      await banned.chat.expectTabHidden(channel);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.addChannelCentralBanException(banned.nick);
      await owner.chat.closeChannelCentral();

      await banned.chat.sendMessage(`/join ${channel}`);
      await banned.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(banned.nick);

      await banned.chat.sendMessage(`/part ${channel}`);
      await banned.chat.expectTabHidden(channel);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.removeChannelCentralBanException(banned.nick);
      await owner.chat.closeChannelCentral();

      await banned.chat.sendMessage(`/join ${channel}`);
      await banned.chat.expectMessageVisible(`You are banned from ${channel}`);
      await banned.chat.expectTabHidden(channel);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.setChannelCentralInviteOnly(true);
      await owner.chat.closeChannelCentral();

      await invited.chat.sendMessage(`/join ${channel}`);
      await invited.chat.expectMessageVisible('Channel is invite-only (+i)');
      await invited.chat.expectTabHidden(channel);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.addChannelCentralInviteException(invited.nick);
      await owner.chat.closeChannelCentral();

      await invited.chat.sendMessage(`/join ${channel}`);
      await invited.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(invited.nick);

      await invited.chat.sendMessage(`/part ${channel}`);
      await invited.chat.expectTabHidden(channel);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.removeChannelCentralInviteException(invited.nick);
      await owner.chat.closeChannelCentral();

      await invited.chat.sendMessage(`/join ${channel}`);
      await invited.chat.expectMessageVisible('Channel is invite-only (+i)');
      await invited.chat.expectTabHidden(channel);
    } finally {
      await closeUsers([owner, banned, invited]);
    }
  });
});
