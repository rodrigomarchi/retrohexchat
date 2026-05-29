import { Browser, BrowserContext, Locator, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

const ADMIN_NICK = 'TestAdmin';
const ADMIN_PW = 'adminpass1';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

function uniqueChannel(prefix = 'sec'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

function uniqueBotName(prefix = 'secbot'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

function uniqueAlias(prefix = 'sec'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

function xssPayload(marker: string): string {
  return `<img data-e2e-xss="${marker}" src=x onerror="window.__e2eXss='${marker}'"><script>window.__e2eXss='${marker}'</script>${marker}`;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'sec',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  await armXssGuard(page);

  return { chat, ctx, page, nick };
}

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();
  await armXssGuard(page);

  return { chat, ctx, page, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function armXssGuard(page: Page) {
  await page.evaluate(() => {
    (window as Window & { __e2eXss?: string }).__e2eXss = 'clean';
  });
}

async function expectNoScriptRan(page: Page) {
  await page.waitForTimeout(300);
  await expect
    .poll(() =>
      page.evaluate(() => (window as Window & { __e2eXss?: string }).__e2eXss),
    )
    .toBe('clean');
}

async function expectEscapedInRoot(root: Locator, marker: string) {
  await expect(root.getByText(marker, { exact: false }).first()).toBeVisible({
    timeout: 10_000,
  });
  await expect(root.locator(`[data-e2e-xss="${marker}"]`)).toHaveCount(0);
  await expect(root.locator('script')).toHaveCount(0);
}

async function expectEscapedMessage(user: TestUser, marker: string) {
  const row = user.chat.messageRows.filter({ hasText: marker }).first();

  await expect(row).toBeVisible({ timeout: 10_000 });
  await expect(row.locator(`[data-e2e-xss="${marker}"]`)).toHaveCount(0);
  await expect(row.locator('script')).toHaveCount(0);
  await expectNoScriptRan(user.page);
}

async function joinChannel(user: TestUser, channel: string) {
  await user.chat.sendMessage(`/join ${channel}`);
  await user.chat.expectTabVisible(channel);
  await user.chat.expectTabSelected(channel);
}

async function cleanupBot(admin: TestUser, botName: string, channel?: string) {
  if (channel) {
    await admin.chat.sendMessage(`/bot part ${botName} ${channel}`).catch(() => {});
  }

  await admin.chat.sendMessage(`/bot destroy ${botName}`).catch(() => {});
}

test.describe('Security escaping', () => {
  test('regular chat messages render HTML/script content as inert text (R1)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'sxsa');
    const bob = await newSignedInUser(browser, 'sxsb');
    const channel = uniqueChannel('xssmsg');
    const marker = `xssmsg-${Date.now()}`;
    const payload = xssPayload(marker);

    try {
      await joinChannel(alice, channel);
      await joinChannel(bob, channel);

      await alice.chat.sendMessage(payload);

      await expectEscapedMessage(alice, marker);
      await expectEscapedMessage(bob, marker);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('topic, channel welcome, and MOTD escape HTML/script content (R2)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const owner = await newSignedInUser(browser, 'sxtp');
    const joiner = await newSignedInUser(browser, 'sxwj');
    const channel = uniqueChannel('xsstw');
    const topicMarker = `xsstopic-${Date.now()}`;
    const welcomeMarker = `xsswelcome-${Date.now()}`;
    const motdMarker = `xssmotd-${Date.now()}`;

    try {
      await joinChannel(owner, channel);

      await owner.chat.sendMessage(`/topic ${xssPayload(topicMarker)}`);
      await expectEscapedInRoot(owner.chat.topicBar, topicMarker);
      await expectNoScriptRan(owner.page);

      await owner.chat.sendMessage(`/setwelcome ${xssPayload(welcomeMarker)}`);
      await owner.chat.expectMessageVisible(`Welcome message for ${channel} has been set.`);

      await joinChannel(joiner, channel);
      await expectEscapedMessage(joiner, welcomeMarker);

      await admin.chat.sendMessage(`/setmotd ${xssPayload(motdMarker)}`);
      await admin.chat.expectMessageVisible('MOTD has been updated.');
      await admin.chat.sendMessage('/motd');
      await admin.chat.switchToStatusTab();
      await expectEscapedInRoot(admin.chat.statusMessageList, motdMarker);
      await expectNoScriptRan(admin.page);
    } finally {
      await owner.chat.sendMessage('/clearwelcome').catch(() => {});
      await admin.chat.sendMessage('/clearmotd').catch(() => {});
      await closeUsers([admin, owner, joiner]);
    }
  });

  test('away and bio text remain escaped in status and whois output (R2)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'sxwa');
    const bob = await newSignedInUser(browser, 'sxwb');
    const channel = uniqueChannel('xsswhois');
    const awayMarker = `xssaway-${Date.now()}`;
    const bioMarker = `xssbio-${Date.now()}`;

    try {
      await joinChannel(alice, channel);
      await joinChannel(bob, channel);

      await bob.chat.sendMessage(`/away ${xssPayload(awayMarker)}`);
      await expectEscapedMessage(bob, awayMarker);

      await bob.chat.sendMessage(`/bio ${xssPayload(bioMarker)}`);
      await expectEscapedMessage(bob, bioMarker);

      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await expectEscapedMessage(alice, awayMarker);
      await expectEscapedMessage(alice, bioMarker);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('alias, bot response, and autorespond output escape HTML/script content (R2)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const owner = await newSignedInUser(browser, 'sxao');
    const visitor = await newSignedInUser(browser, 'sxav');
    const channel = uniqueChannel('xssauto');
    const aliasName = uniqueAlias('xssa');
    const botName = uniqueBotName('xssb');
    const trigger = `ping${Math.random().toString(36).slice(2, 6)}`;
    const aliasMarker = `xssalias-${Date.now()}`;
    const botMarker = `xssbot-${Date.now()}`;
    const autorespondMarker = `xssar-${Date.now()}`;

    try {
      await joinChannel(owner, channel);
      await joinChannel(admin, channel);

      await owner.chat.sendMessage(`/alias add ${aliasName} /me ${xssPayload(aliasMarker)}`);
      await owner.chat.expectMessageVisible(`* Alias /${aliasName} created`);
      await owner.chat.sendMessage(`/${aliasName}`);
      await expectEscapedMessage(owner, aliasMarker);

      await admin.chat.sendMessage(`/bot create ${botName} E2E bot ${botName}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' created successfully.`,
      );
      await admin.chat.sendMessage(`/bot join ${botName} ${channel}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Bot '${botName}' joined ${channel}.`,
      );
      await admin.chat.sendMessage(`/bot addcmd ${botName} ${trigger} ${xssPayload(botMarker)}`);
      await admin.chat.expectMessageVisible(
        `[BotService] Command '${trigger}' set for ${botName}.`,
      );
      await admin.chat.sendMessage(`!${trigger}`);
      await expectEscapedMessage(admin, botMarker);
      await owner.chat.expectMessageVisible(botMarker, 10_000);
      await expectEscapedMessage(owner, botMarker);

      await owner.chat.sendMessage(
        `/autorespond add on_join ${channel} /notice $nick ${xssPayload(autorespondMarker)}`,
      );
      await owner.chat.expectMessageVisible('Auto-respond rule added: on_join');

      await joinChannel(visitor, channel);
      await expectEscapedMessage(visitor, autorespondMarker);
    } finally {
      await owner.chat.sendMessage('/autorespond remove 0').catch(() => {});
      await cleanupBot(admin, botName, channel);
      await closeUsers([admin, owner, visitor]);
    }
  });
});
