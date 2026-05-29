import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'pop'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'pop') {
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
  prefix = 'pop',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Custom menus', () => {
  test('/popups creates custom nicklist and channel menu commands that execute (L18)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'popa');
    const peer = await newSignedInUser(browser, 'popb');
    const channel = uniqueChannel('pop');
    const stamp = Date.now();
    const nickLabel = `Nick Notice ${stamp}`;
    const channelLabel = `Channel Action ${stamp}`;
    const nickText = `custom-nick-menu-${stamp}`;
    const channelText = `custom-channel-menu-${stamp}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);

      await peer.chat.sendMessage(`/join ${channel}`);
      await peer.chat.expectTabVisible(channel);
      await owner.chat.expectNickInList(peer.nick);

      await owner.chat.openCustomMenusDialogFromCommand();
      await owner.chat.addCustomMenuItem(
        'Nicklist',
        nickLabel,
        `/notice $1 ${nickText} $1`,
      );
      await owner.chat.addCustomMenuItem(
        'Channel',
        channelLabel,
        `/me ${channelText} $1`,
      );
      await owner.chat.closeCustomMenusDialog();

      await owner.chat.nicklistItem(peer.nick).click({ button: 'right' });
      await expect(owner.chat.customContextMenuItem(nickLabel)).toBeVisible();
      await owner.chat.customContextMenuItem(nickLabel).click();
      await peer.chat.expectMessageVisible(`${nickText} ${peer.nick}`, 15_000);

      await owner.chat.switchToTab(channel);
      await owner.chat
        .channelConversationItem(channel)
        .click({ button: 'right' });
      await expect(owner.chat.customContextMenuItem(channelLabel)).toBeVisible();
      await owner.chat.customContextMenuItem(channelLabel).click();
      await owner.chat.expectMessageVisible(`${channelText} ${channel}`);
      await peer.chat.switchToTab(channel);
      await peer.chat.expectMessageVisible(`${channelText} ${channel}`, 15_000);
    } finally {
      await closeUsers([owner, peer]);
    }
  });
});
