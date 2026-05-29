import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'flood'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(browser: Browser, prefix: string): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function joinChannel(user: TestUser, channel: string) {
  await user.chat.sendMessage(`/join ${channel}`);
  await user.chat.expectTabVisible(channel);
  await user.chat.expectTabSelected(channel);
}

async function sendPasteLines(chat: ChatPage, lines: string[]) {
  await chat.pasteText(lines.join('\n'));
  await expect(chat.pasteConfirmSendButton).toBeVisible();
  await chat.pasteConfirmSendButton.click();
  await expect(chat.pasteConfirmSendButton).toBeHidden();
}

async function saveStrictFloodProtection(chat: ChatPage) {
  await chat.openFloodProtectionFromToolsMenu();
  await chat.floodThresholdInput.fill('3');
  await chat.floodWindowInput.fill('15');
  await chat.floodAutoIgnoreDurationInput.fill('5');
  await chat.floodSaveButton.click();
  await chat.expectMessageVisible('* Flood protection settings saved');
}

async function resetFloodProtectionDefaults(chat: ChatPage) {
  await chat.openFloodProtectionFromToolsMenu();
  await chat.floodResetDefaultsButton.click();
  await chat.expectMessageVisible('* Flood protection settings reset to defaults');

  await chat.openFloodProtectionFromToolsMenu();
  await expect(chat.floodThresholdInput).toHaveValue('10');
  await expect(chat.floodWindowInput).toHaveValue('15');
  await expect(chat.floodAutoIgnoreDurationInput).toHaveValue('300');
}

test.describe('Flood protection settings', () => {
  test('settings affect rapid paste behavior and reset restores defaults (R8)', async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const alice = await newSignedInUser(browser, 'flooda');
    const bob = await newSignedInUser(browser, 'floodb');
    const charlie = await newSignedInUser(browser, 'floodc');
    const strictMarker = `strict-flood-${Date.now()}`;
    const defaultMarker = `default-flood-${Date.now()}`;
    const strictLines = [1, 2, 3].map((index) => `${strictMarker}-${index}`);
    const defaultLines = [1, 2, 3, 4].map((index) => `${defaultMarker}-${index}`);

    try {
      await joinChannel(alice, channel);
      await joinChannel(bob, channel);
      await joinChannel(charlie, channel);

      await alice.chat.switchToTab(channel);
      await bob.chat.switchToTab(channel);
      await charlie.chat.switchToTab(channel);

      await saveStrictFloodProtection(alice.chat);

      await sendPasteLines(bob.chat, strictLines);
      await alice.chat.expectMessageVisible(strictLines[2]);
      await alice.chat.expectMessageVisible(
        `* ${bob.nick} has been auto-ignored for flooding (5 seconds)`,
      );

      const hiddenAfterIgnore = `${strictMarker}-hidden-after-ignore`;
      await bob.chat.sendMessage(hiddenAfterIgnore);
      await alice.chat.expectMessageHidden(hiddenAfterIgnore);

      await resetFloodProtectionDefaults(alice.chat);

      await sendPasteLines(charlie.chat, defaultLines);
      for (const line of defaultLines) {
        await alice.chat.expectMessageVisible(line);
      }
      await alice.chat.expectMessageHidden(
        `* ${charlie.nick} has been auto-ignored for flooding`,
      );
    } finally {
      await closeUsers([alice, bob, charlie]);
    }
  });
});
