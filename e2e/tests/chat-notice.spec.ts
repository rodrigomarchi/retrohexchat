import { Browser, BrowserContext, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'notice'): string {
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

test.describe('Notice commands', () => {
  test('/notice nick delivers a notice without opening a PM tab (J2)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'nota');
    const bob = await newSignedInUser(browser, 'notb');
    const text = `notice-direct-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/notice ${bob.nick} ${text}`);

      await bob.chat.expectMessageVisible(text);
      await bob.chat.expectTabHidden(alice.nick);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('/notice #room stays in the channel buffer while another tab is active (J3)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('not');
    const alice = await newSignedInUser(browser, 'ncha');
    const bob = await newSignedInUser(browser, 'nchb');
    const activeText = `notice-channel-active-${Date.now()}`;
    const hiddenText = `notice-channel-hidden-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabSelected(channel);

      await alice.chat.sendMessage(`/notice ${channel} ${activeText}`);
      await bob.chat.expectMessageVisible(activeText);

      await bob.chat.switchToStatusTab();
      await alice.chat.sendMessage(`/notice ${channel} ${hiddenText}`);
      await bob.chat.expectMessageNotVisible(hiddenText);

      await bob.chat.switchToTab(channel);
      await bob.chat.expectMessageVisible(hiddenText);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('/notice_routing reports active-window routing without switching tabs (J4)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'nrta');

    try {
      await alice.chat.switchToStatusTab();
      await alice.chat.sendMessage('/notice_routing');

      await alice.chat.expectTabSelected('Status');
      await alice.chat.expectStatusMessageVisible(
        'Notice routing is hardcoded to: active',
      );
    } finally {
      await closeUsers([alice]);
    }
  });
});
