import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'modes'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'modes') {
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
  prefix = 'modes',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectChannelCentralModeMatrix(
  chat: ChatPage,
  key: string,
  limit: string,
) {
  await chat.switchChannelCentralToTab('modes');
  const panel = chat.channelCentralPanel('modes');

  await expect(panel.getByLabel('Moderated (+m)')).toBeChecked();
  await expect(panel.getByLabel('Invite Only (+i)')).toBeChecked();
  await expect(panel.getByLabel('Topic Lock (+t)')).toBeChecked();
  await expect(panel.getByLabel('Key (+k):')).toBeChecked();
  await expect(panel.getByTestId('cc-key-input')).toHaveValue(key);
  await expect(panel.getByLabel('Limit (+l):')).toBeChecked();
  await expect(panel.getByTestId('cc-limit-input')).toHaveValue(limit);
}

async function expectChannelCentralKeyLimitState(
  chat: ChatPage,
  keyEnabled: boolean,
  limitEnabled: boolean,
) {
  await chat.switchChannelCentralToTab('modes');
  const panel = chat.channelCentralPanel('modes');
  const keyToggle = panel.getByLabel('Key (+k):');
  const limitToggle = panel.getByLabel('Limit (+l):');

  if (keyEnabled) {
    await expect(keyToggle).toBeChecked();
  } else {
    await expect(keyToggle).not.toBeChecked();
    await expect(panel.getByTestId('cc-key-input')).toHaveValue('');
  }

  if (limitEnabled) {
    await expect(limitToggle).toBeChecked();
  } else {
    await expect(limitToggle).not.toBeChecked();
    await expect(panel.getByTestId('cc-limit-input')).toHaveValue('');
  }
}

test.describe('Channel mode matrix', () => {
  test('combined +imntkl modes survive Channel Central reopen and mode output (X1)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'x1o');
    const channel = uniqueChannel('x1mode');
    const key = `key${Date.now()}`;
    const limit = '3';

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await owner.chat.sendMessage(`/mode +imntkl ${key} ${limit}`);
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode +imntkl`);
      await expect(owner.chat.topicBar).toContainText('+imntkl');

      await owner.chat.openChannelCentralFromMenu();
      await expectChannelCentralModeMatrix(owner.chat, key, limit);
      await owner.chat.closeChannelCentral();

      await owner.chat.openChannelCentralFromMenu();
      await expectChannelCentralModeMatrix(owner.chat, key, limit);
      await owner.chat.closeChannelCentral();
    } finally {
      await closeUsers([owner]);
    }
  });

  test('removing +k and +l clears visible state and join restrictions (X2)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'x2o');
    const guest = await newSignedInUser(browser, 'x2g');
    const overflow = await newSignedInUser(browser, 'x2f');
    const channel = uniqueChannel('x2mode');
    const key = `key${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await owner.chat.sendMessage(`/mode +k ${key}`);
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode +k`);
      await expect(owner.chat.topicBar).toContainText('+k');

      await guest.chat.sendMessage(`/join ${channel}`);
      await guest.chat.expectMessageVisible('Bad channel key (+k)');
      await guest.chat.expectTabHidden(channel);

      await owner.chat.sendMessage('/mode -k');
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode -k`);
      await expect(owner.chat.topicBar).not.toContainText('+k');

      await owner.chat.openChannelCentralFromMenu();
      await expectChannelCentralKeyLimitState(owner.chat, false, false);
      await owner.chat.closeChannelCentral();

      await guest.chat.sendMessage(`/join ${channel}`);
      await guest.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(guest.nick);

      await owner.chat.sendMessage('/mode +l 2');
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode +l`);
      await expect(owner.chat.topicBar).toContainText('+l');

      await overflow.chat.sendMessage(`/join ${channel}`);
      await overflow.chat.expectMessageVisible('Channel is full (+l)');
      await overflow.chat.expectTabHidden(channel);

      await owner.chat.sendMessage('/mode -l');
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode -l`);
      await expect(owner.chat.topicBar).not.toContainText('+l');

      await owner.chat.openChannelCentralFromMenu();
      await expectChannelCentralKeyLimitState(owner.chat, false, false);
      await owner.chat.closeChannelCentral();

      await overflow.chat.sendMessage(`/join ${channel}`);
      await overflow.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(overflow.nick);
    } finally {
      await closeUsers([owner, guest, overflow]);
    }
  });
});
