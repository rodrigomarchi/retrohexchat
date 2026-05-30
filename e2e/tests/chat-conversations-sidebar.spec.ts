import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'conv'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'conv') {
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
  prefix = 'conv',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Conversations sidebar', () => {
  test('section collapse survives unread rerender without changing active tab (V1)', async ({
    browser,
  }) => {
    const channelA = uniqueChannel('conva');
    const channelB = uniqueChannel('convb');
    const alice = await newSignedInUser(browser, 'cva');
    const bob = await newSignedInUser(browser, 'cvb');
    const unreadMessage = `collapsed-sidebar-unread-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channelA}`);
      await alice.chat.expectTabVisible(channelA);
      await alice.chat.sendMessage(`/join ${channelB}`);
      await alice.chat.expectTabVisible(channelB);

      await bob.chat.sendMessage(`/join ${channelA}`);
      await bob.chat.expectTabVisible(channelA);
      await bob.chat.sendMessage(`/join ${channelB}`);
      await bob.chat.expectTabVisible(channelB);

      await alice.chat.switchToTab(channelA);
      await alice.chat.expectTabSelected(channelA);
      await bob.chat.switchToTab(channelB);

      await alice.chat.expectConversationSectionExpanded('channels', true);
      await alice.chat.toggleConversationSection('channels');
      await alice.chat.expectConversationSectionExpanded('channels', false);
      await alice.chat.expectTabSelected(channelA);

      await bob.chat.sendMessage(unreadMessage);

      await alice.chat.expectConversationSectionExpanded('channels', false);
      await alice.chat.expectTabSelected(channelA);
      await alice.chat.expectMessageHidden(unreadMessage);

      await alice.chat.toggleConversationSection('channels');
      await alice.chat.expectConversationSectionExpanded('channels', true);
      await expect(alice.chat.channelConversationItem(channelA)).toBeVisible();
      await expect(alice.chat.channelConversationItem(channelB)).toBeVisible();
      await expect(alice.chat.channelUnreadBadge(channelB)).toBeVisible();
      await alice.chat.expectTabSelected(channelA);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('popular channel item joins and switches channel through the sidebar (V2)', async ({
    browser,
  }) => {
    const popularChannel = uniqueChannel('popular');
    const alice = await newSignedInUser(browser, 'cpa');
    const bob = await newSignedInUser(browser, 'cpb');

    try {
      await bob.chat.sendMessage(`/join ${popularChannel}`);
      await bob.chat.expectTabVisible(popularChannel);

      await alice.chat.joinPopularChannel(popularChannel);
      await expect(alice.chat.channelConversationItem(popularChannel)).toBeVisible();
      await expect(alice.chat.popularChannelItem(popularChannel)).toHaveCount(0);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('browse all channels from sidebar preserves channel list search pre-state (V3)', async ({
    browser,
  }) => {
    const homeChannel = uniqueChannel('home');
    const targetChannel = uniqueChannel('browse');
    const searchTerm = targetChannel.slice(1);
    const alice = await newSignedInUser(browser, 'cba');
    const bob = await newSignedInUser(browser, 'cbb');

    try {
      await bob.chat.sendMessage(`/join ${targetChannel}`);
      await bob.chat.expectTabVisible(targetChannel);

      await alice.chat.sendMessage(`/join ${homeChannel}`);
      await alice.chat.expectTabVisible(homeChannel);
      await alice.chat.expectTabSelected(homeChannel);

      await alice.chat.sendMessage('/list');
      await expect(alice.chat.channelListDialog).toBeVisible();
      await expect(alice.chat.channelListJoinButton).toBeDisabled();
      await alice.chat.channelListSearch.fill(searchTerm);
      await expect(alice.chat.channelListRow(targetChannel)).toBeVisible();

      await alice.chat.closeChannelList();
      await alice.chat.expectTabSelected(homeChannel);

      await alice.chat.browseAllChannelsFromConversations();
      await expect(alice.chat.channelListSearch).toHaveValue(searchTerm);
      await expect(alice.chat.channelListRow(targetChannel)).toBeVisible();
      await expect(alice.chat.channelListJoinButton).toBeDisabled();

      await alice.chat.channelListRow(targetChannel).click();
      await expect(alice.chat.channelListJoinButton).toBeEnabled();
      await alice.chat.channelListJoinButton.click();
      await alice.chat.expectTabVisible(targetChannel);
      await alice.chat.expectTabSelected(targetChannel);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
