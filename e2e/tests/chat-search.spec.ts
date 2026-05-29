import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'search'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'srch') {
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
  prefix = 'srch',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'sra');
  const bob = await newSignedInUser(browser, 'srb');

  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);

  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);

  await alice.chat.switchToTab(channel);
  await alice.chat.expectNickInList(bob.nick);

  return { alice, bob };
}

function activeHighlightRow(chat: ChatPage) {
  return chat.searchActiveHighlight.locator(
    'xpath=ancestor::*[@data-message-id][1]',
  );
}

async function expectSearchCount(chat: ChatPage, current: number, total: number) {
  await expect(chat.searchBarCount).toHaveText(`${current}/${total}`);
}

test.describe('Chat search bar', () => {
  test('opens from View > Find, highlights matches, navigates, and reports invalid regex (O6)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);
    const marker = `find${Date.now()}`;
    const first = `${marker}-first`;
    const second = `${marker}-second`;

    await chat.sendMessage(`alpha ${first}`);
    await chat.sendMessage(`alpha ${second}`);
    await chat.expectMessageVisible(first);
    await chat.expectMessageVisible(second);

    await chat.openSearchFromViewMenu();
    await chat.searchBarInput.fill(marker);

    await expect(chat.searchHighlights).toHaveCount(2);
    await expectSearchCount(chat, 1, 2);
    await expect(activeHighlightRow(chat)).toContainText(first);

    await chat.searchBarNextButton.click();
    await expectSearchCount(chat, 2, 2);
    await expect(activeHighlightRow(chat)).toContainText(second);

    await chat.searchBarPrevButton.click();
    await expectSearchCount(chat, 1, 2);
    await expect(activeHighlightRow(chat)).toContainText(first);

    await chat.searchBarRegex.click();
    await chat.searchBarInput.fill('[');

    await expect(chat.searchBar).toContainText('Invalid regex');
    await expect(chat.searchHighlights).toHaveCount(0);
  });

  test('case-sensitive, regex, my-mentions, and history options stay active while search remains open (O7)', async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const suffix = Date.now().toString(36);
    const lowerNeedle = `case${suffix}`;
    const upperNeedle = `Case${suffix}`;
    const regexPrefix = `rx${suffix}`;
    const mentionNeedle = `mention${suffix}`;

    try {
      await bob.chat.sendMessage(`${lowerNeedle} for ${alice.nick}`);
      await bob.chat.sendMessage(`${upperNeedle} for ${alice.nick}`);
      await alice.chat.expectMessageVisible(lowerNeedle);
      await alice.chat.expectMessageVisible(upperNeedle);

      await alice.chat.openSearchFromViewMenu();
      await alice.chat.searchBarInput.fill(lowerNeedle);
      await expectSearchCount(alice.chat, 1, 2);

      await alice.chat.searchBarCaseSensitive.click();
      await expect(alice.chat.searchBarCaseSensitive).toBeChecked();
      await expectSearchCount(alice.chat, 1, 1);
      await expect(alice.chat.searchBar).toBeVisible();

      await bob.chat.sendMessage(`${regexPrefix}-123 for ${alice.nick}`);
      await bob.chat.sendMessage(`${regexPrefix}-abc for ${alice.nick}`);
      await alice.chat.expectMessageVisible(`${regexPrefix}-123`);
      await alice.chat.expectMessageVisible(`${regexPrefix}-abc`);

      await alice.chat.searchBarInput.fill(`${regexPrefix}-\\d+`);
      await expectSearchCount(alice.chat, 0, 0);

      await alice.chat.searchBarRegex.click();
      await expect(alice.chat.searchBarRegex).toBeChecked();
      await expectSearchCount(alice.chat, 1, 1);
      await expect(alice.chat.searchBar).toBeVisible();

      await bob.chat.sendMessage(`${mentionNeedle} for ${alice.nick}`);
      await bob.chat.sendMessage(`${mentionNeedle} for nobody`);
      await alice.chat.expectMessageVisible(`${mentionNeedle} for ${alice.nick}`);
      await alice.chat.expectMessageVisible(`${mentionNeedle} for nobody`);

      await alice.chat.searchBarInput.fill(mentionNeedle);
      await expectSearchCount(alice.chat, 1, 2);

      await alice.chat.searchBarMyMentions.click();
      await expect(alice.chat.searchBarMyMentions).toBeChecked();
      await expectSearchCount(alice.chat, 1, 1);
      await expect(activeHighlightRow(alice.chat)).toContainText(alice.nick);

      await alice.chat.searchBarHistory.click();
      await expect(alice.chat.searchBarHistory).toBeChecked();
      await expect(alice.chat.searchBarCaseSensitive).toBeChecked();
      await expect(alice.chat.searchBarRegex).toBeChecked();
      await expect(alice.chat.searchBarMyMentions).toBeChecked();
      await expect(alice.chat.searchBarInput).toHaveValue(mentionNeedle);
      await expect(alice.chat.searchBar).toBeVisible();
    } finally {
      await alice.ctx.close();
      await bob.ctx.close();
    }
  });
});
