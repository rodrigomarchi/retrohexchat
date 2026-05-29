import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'alias'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

function uniqueAlias(prefix = 'a'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
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

test.describe('Alias commands', () => {
  test('/alias add, execute, list, and remove basic alias (L1)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'alia');
    const alias = uniqueAlias('hi');
    const text = `alias-basic-${Date.now()}`;

    try {
      await user.chat.sendMessage(`/alias add ${alias} /me ${text}`);
      await user.chat.expectMessageVisible(`* Alias /${alias} created`);

      await user.chat.sendMessage(`/${alias}`);
      await user.chat.expectMessageVisible(text);

      await user.chat.sendMessage('/clear');
      await user.chat.sendMessage('/alias list');
      await user.chat.expectMessageVisible(`/${alias}`);
      await user.chat.expectMessageVisible(`/me ${text}`);

      await user.chat.sendMessage(`/alias remove ${alias}`);
      await user.chat.expectMessageVisible(`* Alias /${alias} removed`);

      await user.chat.sendMessage('/clear');
      await user.chat.sendMessage('/alias list');
      await user.chat.expectMessageVisible('Your alias list is empty');
    } finally {
      await closeUsers([user]);
    }
  });

  test('alias variables $1, $nick, $chan, and $$ expand correctly (L2)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'aliv');
    const channel = uniqueChannel('vars');
    const alias = uniqueAlias('vars');
    const target = uniqueNickname('arg');

    try {
      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);

      await user.chat.sendMessage(
        `/alias add ${alias} /me ${user.nick} greets $1 in $chan for $$5`,
      );
      await user.chat.expectMessageVisible(`* Alias /${alias} created`);

      await user.chat.sendMessage(`/${alias} ${target}`);
      await user.chat.expectMessageVisible(
        `${user.nick} greets ${target} in ${channel} for $5`,
      );
    } finally {
      await closeUsers([user]);
    }
  });

  test('alias recursion stops at the recursion limit (L3)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'alir');
    const alias = uniqueAlias('loop');

    try {
      await user.chat.sendMessage(`/alias add ${alias} /${alias}`);
      await user.chat.expectMessageVisible(`* Alias /${alias} created`);

      await user.chat.sendMessage(`/${alias}`);
      await user.chat.expectMessageVisible(
        'Alias recursion limit reached (max 5 levels)',
      );
    } finally {
      await closeUsers([user]);
    }
  });

  test('alias expansion rejects command chaining characters (L4)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'alic');
    const alias = uniqueAlias('bad');

    try {
      await user.chat.sendMessage(`/alias add ${alias} /me hello && /quit`);
      await user.chat.expectMessageVisible(
        'Expansion must not contain command chaining',
      );

      await user.chat.sendMessage('/clear');
      await user.chat.sendMessage('/alias list');
      await user.chat.expectMessageVisible('Your alias list is empty');
    } finally {
      await closeUsers([user]);
    }
  });
});
