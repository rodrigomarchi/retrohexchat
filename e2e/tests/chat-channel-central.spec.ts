import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'cc'): string {
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

test.describe('Channel Central', () => {
  test('dialog edits modes, key, and limit; slash commands respect the result (I18)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('cc');
    const key = `key${Date.now()}`;
    const owner = await newSignedInUser(browser, 'own');
    const wrongKeyGuest = await newSignedInUser(browser, 'bad');
    const member = await newSignedInUser(browser, 'mem');
    const overflow = await newSignedInUser(browser, 'ful');
    const blockedMessage = `cc-muted-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.openChannelCentralFromMenu();

      const dialog = owner.chat.channelCentralDialog;
      await dialog.locator('button[data-target="modes"]').click();

      const modesPanel = dialog.locator('.tabs-content[value="modes"]');
      await expect(modesPanel).toBeVisible();
      await modesPanel.getByLabel('Moderated (+m)').check();
      await modesPanel.getByLabel('Key (+k):').check();
      await modesPanel.getByTestId('cc-key-input').fill(key);
      await modesPanel.getByLabel('Limit (+l):').check();
      await modesPanel.getByTestId('cc-limit-input').fill('2');
      await modesPanel.getByRole('button', { name: 'Apply Modes' }).click();

      await expect(modesPanel.getByLabel('Moderated (+m)')).toBeChecked();
      await expect(modesPanel.getByLabel('Key (+k):')).toBeChecked();
      await expect(modesPanel.getByTestId('cc-key-input')).toHaveValue(key);
      await expect(modesPanel.getByLabel('Limit (+l):')).toBeChecked();
      await expect(modesPanel.getByTestId('cc-limit-input')).toHaveValue('2');

      await owner.chat.closeChannelCentral();

      await wrongKeyGuest.chat.sendMessage(`/join ${channel} wrong`);
      await wrongKeyGuest.chat.expectMessageVisible('Bad channel key (+k)');
      await wrongKeyGuest.chat.expectTabHidden(channel);

      await member.chat.sendMessage(`/join ${channel} ${key}`);
      await member.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(member.nick);

      await member.chat.sendMessage(blockedMessage);
      await member.chat.expectMessageVisible(
        'Channel is moderated (+m). You need voice (+v) to speak.',
      );
      await owner.chat.expectMessageHidden(blockedMessage);

      await overflow.chat.sendMessage(`/join ${channel} ${key}`);
      await overflow.chat.expectMessageVisible('Channel is full (+l)');
      await overflow.chat.expectTabHidden(channel);
    } finally {
      await closeUsers([owner, wrongKeyGuest, member, overflow]);
    }
  });
});
