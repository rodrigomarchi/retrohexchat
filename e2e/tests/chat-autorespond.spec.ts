import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'ar'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'ar') {
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
  prefix = 'ar',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Auto-respond commands', () => {
  test('/autorespond on_join fires when another user joins the channel (L12)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'arja');
    const visitor = await newSignedInUser(browser, 'arjb');
    const channel = uniqueChannel('arjoin');
    const greeting = `autorespond-join-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await owner.chat.sendMessage(
        `/autorespond add on_join ${channel} /notice $nick ${greeting}`,
      );
      await owner.chat.expectMessageVisible('Auto-respond rule added: on_join');

      await visitor.chat.sendMessage(`/join ${channel}`);
      await visitor.chat.expectTabVisible(channel);
      await visitor.chat.expectMessageVisible(greeting, 15_000);
    } finally {
      await closeUsers([owner, visitor]);
    }
  });

  test('autorespond on_part fires with $nick expansion (L13)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'arpa');
    const visitor = await newSignedInUser(browser, 'arpb');
    const channel = uniqueChannel('arpart');
    const partText = `autorespond-part-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await visitor.chat.sendMessage(`/join ${channel}`);
      await visitor.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(visitor.nick);

      await owner.chat.sendMessage(
        `/autorespond add on_part ${channel} /notice $nick ${partText} $nick`,
      );
      await owner.chat.expectMessageVisible('Auto-respond rule added: on_part');

      await visitor.chat.sendMessage(`/part ${channel}`);
      await visitor.chat.expectTabHidden(channel);
      await visitor.chat.expectMessageVisible(
        `${partText} ${visitor.nick}`,
        15_000,
      );
    } finally {
      await closeUsers([owner, visitor]);
    }
  });

  test('autorespond on_nick_change fires with $nick expansion (L13)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'arna');
    const visitor = await newSignedInUser(browser, 'arnb');
    const channel = uniqueChannel('arnick');
    const nickText = `autorespond-nick-${Date.now()}`;
    const newNick = uniqueNickname('arn');

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await visitor.chat.sendMessage(`/join ${channel}`);
      await visitor.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(visitor.nick);

      await owner.chat.sendMessage(
        `/autorespond add on_nick_change /notice $nick ${nickText} $nick`,
      );
      await owner.chat.expectMessageVisible(
        'Auto-respond rule added: on_nick_change',
      );

      await visitor.chat.sendMessage(`/nick ${newNick}`);
      await visitor.chat.confirmNickChange();
      await visitor.chat.expectMessageVisible(`${nickText} ${newNick}`, 15_000);
    } finally {
      await closeUsers([owner, visitor]);
    }
  });

  test('/autorespond list/remove and command-chaining validation (L14)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'arla');
    const channel = uniqueChannel('arlist');
    const validText = `autorespond-valid-${Date.now()}`;
    const invalidText = `autorespond-invalid-${Date.now()}`;

    try {
      await owner.chat.sendMessage(
        `/autorespond add on_join ${channel} /notice $nick ${validText}`,
      );
      await owner.chat.expectMessageVisible('Auto-respond rule added: on_join');

      await owner.chat.sendMessage(
        `/autorespond add on_join ${channel} /notice $nick ${invalidText} && /quit`,
      );
      await owner.chat.expectMessageVisible(
        'Error adding auto-respond rule: Command must not contain chaining',
      );

      await owner.chat.sendMessage('/clear');
      await owner.chat.sendMessage('/autorespond list');
      await owner.chat.expectMessageVisible('Auto-respond rules:');
      await owner.chat.expectMessageVisible(`0: [ON] on_join ${channel}`);
      await owner.chat.expectMessageVisible(validText);
      await owner.chat.expectMessageHidden(invalidText);

      await owner.chat.sendMessage('/autorespond remove 0');
      await owner.chat.expectMessageVisible('Auto-respond rule removed.');

      await owner.chat.sendMessage('/clear');
      await owner.chat.sendMessage('/autorespond list');
      await owner.chat.expectMessageVisible('No auto-respond rules configured.');
    } finally {
      await closeUsers([owner]);
    }
  });
});
