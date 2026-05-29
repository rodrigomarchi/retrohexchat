import { Browser, BrowserContext, expect, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';
import { uniqueChannel } from '../helpers/commandRegistry';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

async function signedInUser(page: Page, prefix = 'qparse') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return { chat, nick };
}

async function newUser(browser: Browser, prefix: string): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);
  return { chat, ctx, nick };
}

test.describe('Command parser behavior', () => {
  test('slash commands are case-insensitive for channel, PM, and service handlers (Q5)', async ({
    browser,
  }) => {
    const alice = await newUser(browser, 'qcasea');
    const bob = await newUser(browser, 'qcaseb');
    const channel = uniqueChannel('qcase');
    const pmText = `case-pm-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/JOIN ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await alice.chat.switchToTab('#lobby');
      await alice.chat.expectNickInList(bob.nick);

      await alice.chat.sendMessage(`/Msg ${bob.nick} ${pmText}`);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await bob.chat.expectMessageVisible(pmText);

      await alice.chat.switchToTab('#lobby');
      await alice.chat.sendMessage('/Ns info');
      await alice.chat.expectMessageVisible('[NickServ]');
    } finally {
      await alice.ctx.close();
      await bob.ctx.close();
    }
  });

  test('leading and trailing whitespace around commands and args keeps dispatch behavior (Q6)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'qspace');
    const channel = uniqueChannel('qspace');
    const topic = `topic punctuation !? ${Date.now()}`;

    await chat.sendMessage(`   /join   ${channel}   `);
    await chat.expectTabVisible(channel);
    await chat.expectTabSelected(channel);

    await chat.sendMessage(`   /topic   ${topic}   `);
    await expect(chat.topicBar).toContainText(topic);
  });

  test('bare slash inputs show a helpful error without changing the active tab (Q7)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'qbare');

    await chat.switchToTab('#lobby');
    await chat.sendMessage('/');
    await chat.expectMessageVisible('Unknown command: /. Type /help');
    await chat.expectTabSelected('#lobby');

    await chat.sendMessage('/   ');
    await chat.expectMessageVisible('Unknown command: /. Type /help');
    await chat.expectTabSelected('#lobby');
  });

  test('free-text command arguments preserve punctuation, spacing, unicode, and IRC formatting (Q8)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'qargs');
    const channel = uniqueChannel('qargs');
    const content = `waves: áéí -- hello  there   \x02bold\x02 !?`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage(`/me ${content}`);

    const row = chat.messageRowByText('waves: áéí');
    await expect(row).toBeVisible();
    await expect
      .poll(async () => row.evaluate((el) => el.textContent || ''))
      .toContain('waves: áéí -- hello  there   bold !?');
  });
});
