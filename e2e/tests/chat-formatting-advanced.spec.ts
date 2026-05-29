import {
  Browser,
  BrowserContext,
  Page,
  test,
  expect,
  Locator,
} from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname('fmt'));
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return chat;
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'fmt',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, ctx, page, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectButtonInserts(
  chat: ChatPage,
  button: Locator,
  code: string,
) {
  await chat.chatInput.fill('');
  await button.click();
  await expect(chat.chatInput).toHaveValue(code);
  await expect(chat.chatInput).toBeFocused();
}

function formattedMessageRow(chat: ChatPage, marker: string): Locator {
  return chat.messageRows.filter({ hasText: marker }).first();
}

async function expectRenderedFormatting(chat: ChatPage, marker: string) {
  const row = formattedMessageRow(chat, marker);
  await expect(row).toBeVisible();
  await expect(row.locator('.irc-bold')).toContainText(`bold-${marker}`);
  await expect(row.locator('.irc-fg-4')).toContainText(`red-${marker}`);
}

async function expectStrippedFormatting(chat: ChatPage, marker: string) {
  const row = formattedMessageRow(chat, marker);
  await expect(row).toContainText(`bold-${marker} red-${marker}`);
  await expect(row.locator('.irc-bold')).toHaveCount(0);
  await expect(row.locator('.irc-fg-4')).toHaveCount(0);
}

test.describe('Advanced formatting toolbar', () => {
  test('format buttons insert IRC italic, underline, color, reverse, and reset codes (O2)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await expectButtonInserts(chat, chat.formatItalicButton, '\x1D');
    await expectButtonInserts(chat, chat.formatUnderlineButton, '\x1F');
    await expectButtonInserts(chat, chat.formatReverseButton, '\x16');
    await expectButtonInserts(chat, chat.formatResetButton, '\x0F');

    await chat.chatInput.fill('');
    await chat.formatColorButton.click();
    await chat.formatColorSwatch(4).click();
    await expect(chat.chatInput).toHaveValue('\x034');
    await expect(chat.chatInput).toBeFocused();
  });

  test('strip formatting toggle affects sent and received formatted messages (O3)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'fmta');
    const bob = await newSignedInUser(browser, 'fmtb');
    const marker = `strip-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`\x02bold-${marker}\x02 \x034red-${marker}`);

      await expectRenderedFormatting(alice.chat, marker);
      await expectRenderedFormatting(bob.chat, marker);

      await bob.chat.stripFormattingToggle.click();
      await expectStrippedFormatting(bob.chat, marker);
      await expectRenderedFormatting(alice.chat, marker);

      await alice.chat.stripFormattingToggle.click();
      await expectStrippedFormatting(alice.chat, marker);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
