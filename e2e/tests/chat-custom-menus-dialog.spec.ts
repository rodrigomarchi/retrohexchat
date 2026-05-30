import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'cmdlg'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'cmdlg') {
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
  prefix = 'cmdlg',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Custom Menus dialog', () => {
  test('validates invalid entries and scopes items to their menu type (U9)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'cmda');
    const peer = await newSignedInUser(browser, 'cmdb');
    const channel = uniqueChannel('cmdlg');
    const stamp = Date.now();
    const nickLabel = `Nick Only ${stamp}`;
    const channelLabel = `Channel Only ${stamp}`;
    const chatLabel = `Chat Only ${stamp}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await peer.chat.sendMessage(`/join ${channel}`);
      await peer.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(peer.nick);

      await owner.chat.openCustomMenusDialogFromMenu();
      await owner.chat.addCustomMenuItem(
        'Nicklist',
        nickLabel,
        `/notice $1 custom-nick-${stamp}`,
      );

      await owner.chat.startCustomMenuAdd('Nicklist');
      await owner.chat.fillCustomMenuDraft(
        nickLabel.toUpperCase(),
        `/notice $1 duplicate-${stamp}`,
      );
      await owner.chat.saveCustomMenuDraft();
      await owner.chat.expectCustomMenuError(
        'An item with that label already exists',
      );

      await owner.chat.fillCustomMenuDraft(`Empty Command ${stamp}`, '');
      await owner.chat.saveCustomMenuDraft();
      await owner.chat.expectCustomMenuError('Command is required');

      await owner.chat.fillCustomMenuDraft(
        `Chained Command ${stamp}`,
        `/notice $1 one && /notice $1 two`,
      );
      await owner.chat.saveCustomMenuDraft();
      await owner.chat.expectCustomMenuError(
        'Command must not contain chaining',
      );

      await owner.chat.addCustomMenuItem(
        'Channel',
        channelLabel,
        `/me custom-channel-${stamp} $1`,
      );
      await owner.chat.addCustomMenuItem(
        'Chat',
        chatLabel,
        `/me custom-chat-${stamp} $1`,
      );
      await owner.chat.closeCustomMenusDialog();

      await owner.chat.openNicklistContextMenu(peer.nick);
      await expect(owner.chat.customNicklistContextMenuItem(nickLabel))
        .toBeVisible();
      await expect(owner.chat.customNicklistContextMenuItem(channelLabel))
        .toHaveCount(0);
      await expect(owner.chat.customNicklistContextMenuItem(chatLabel))
        .toHaveCount(0);

      await owner.chat.page.keyboard.press('Escape');
      await owner.chat.switchToTab(channel);
      await owner.chat.openConversationContextMenu(channel);
      await expect(owner.chat.customConversationContextMenuItem(channelLabel))
        .toBeVisible();
      await expect(owner.chat.customConversationContextMenuItem(nickLabel))
        .toHaveCount(0);
      await expect(owner.chat.customConversationContextMenuItem(chatLabel))
        .toHaveCount(0);

      await owner.chat.page.keyboard.press('Escape');
      await peer.chat.sendMessage(`message for chat menu ${stamp}`);
      await owner.chat.expectMessageVisible(`message for chat menu ${stamp}`);
      await owner.chat.openChatNickContextMenu(
        `message for chat menu ${stamp}`,
        peer.nick,
      );
      await expect(owner.chat.customChatContextMenuItem(chatLabel))
        .toBeVisible();
      await expect(owner.chat.customChatContextMenuItem(nickLabel))
        .toHaveCount(0);
      await expect(owner.chat.customChatContextMenuItem(channelLabel))
        .toHaveCount(0);
    } finally {
      await closeUsers([owner, peer]);
    }
  });
});
