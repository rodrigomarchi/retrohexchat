import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
  page: Page;
};

function uniqueChannel(prefix = 'muteconv'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function installAudioSpy(page: Page) {
  await page.addInitScript(() => {
    class FakeAudioParam {
      setValueAtTime() {}
      exponentialRampToValueAtTime() {}
    }

    class FakeOscillatorNode {
      frequency = new FakeAudioParam();
      type = 'sine';

      connect() {}
      start() {
        (window as unknown as { __soundStartCount: number }).__soundStartCount += 1;
      }
      stop() {}
    }

    class FakeGainNode {
      gain = new FakeAudioParam();

      connect() {}
    }

    class FakeAudioContext {
      currentTime = 0;
      destination = {};

      createOscillator() {
        return new FakeOscillatorNode();
      }

      createGain() {
        return new FakeGainNode();
      }
    }

    (window as unknown as { __soundStartCount: number }).__soundStartCount = 0;
    (window as unknown as { AudioContext: typeof FakeAudioContext }).AudioContext =
      FakeAudioContext;
    (
      window as unknown as { webkitAudioContext: typeof FakeAudioContext }
    ).webkitAudioContext = FakeAudioContext;
  });
}

async function signedInUser(page: Page, prefix = 'muteconv', spyAudio = false) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  if (spyAudio) {
    await installAudioSpy(page);
  }

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'muteconv',
  spyAudio = false,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix, spyAudio);

  return { chat: user.chat, ctx, nick: user.nick, page };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function resetNotificationSpies(page: Page) {
  await page.evaluate(() => {
    (window as unknown as { __soundStartCount: number }).__soundStartCount = 0;
  });
}

async function expectNoSoundStarts(page: Page) {
  await page.waitForTimeout(500);
  await expect
    .poll(() =>
      page.evaluate(
        () => (window as unknown as { __soundStartCount: number }).__soundStartCount,
      ),
    )
    .toBe(0);
}

async function expectNoTitleFlash(page: Page, stableTitle: string) {
  await page.waitForTimeout(1_700);
  await expect(page).toHaveTitle(stableTitle);
}

async function enableSoundAndFlash(chat: ChatPage, event: 'message' | 'pm') {
  await chat.openSoundSettingsFromMenu();
  await chat.selectSound(event, 'Beep');
  await chat.setSoundFlash(event, true);
  await chat.soundSettingsDialog.getByRole('button', { name: 'OK' }).click();
  await expect(chat.soundSettingsDialog).toBeHidden();
}

test.describe('Conversation mute notifications', () => {
  test('muted channel suppresses sound and title flash while keeping unread indicators (V5)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('mutec');
    const message = `muted-channel-notify-${Date.now()}`;
    const alice = await newSignedInUser(browser, 'v5ca');
    const bob = await newSignedInUser(browser, 'v5cb', true);

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);

      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.switchToTab('#lobby');
      await bob.chat.expectTabSelected('#lobby');

      await enableSoundAndFlash(bob.chat, 'message');
      await bob.chat.openConversationContextMenu(channel);
      await expect(bob.chat.conversationsMuteMenuItem).toContainText(
        'Mute Channel',
      );
      await bob.chat.conversationsMuteMenuItem.click();
      await bob.chat.expectChannelConversationMuted(channel, true);

      const stableTitle = await bob.page.title();
      await resetNotificationSpies(bob.page);
      await alice.chat.sendMessage(message);

      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabUnread(channel, true);
      await bob.chat.expectChannelConversationUnread(channel, true);
      await expect(bob.chat.channelUnreadBadge(channel)).toHaveText('1');
      await bob.chat.expectChannelConversationMuted(channel, true);
      await bob.chat.expectMessageHidden(message);
      await expectNoSoundStarts(bob.page);
      await expectNoTitleFlash(bob.page, stableTitle);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('muted PM suppresses sound and title flash while keeping unread indicators (V5)', async ({
    browser,
  }) => {
    const message = `muted-pm-notify-${Date.now()}`;
    const alice = await newSignedInUser(browser, 'v5pa');
    const bob = await newSignedInUser(browser, 'v5pb', true);

    try {
      await bob.chat.sendMessage(`/query ${alice.nick}`);
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab('#lobby');
      await bob.chat.expectTabSelected('#lobby');

      await enableSoundAndFlash(bob.chat, 'pm');
      await bob.chat.openPmConversationContextMenu(alice.nick);
      await expect(bob.chat.conversationsMuteMenuItem).toContainText('Mute PM');
      await bob.chat.conversationsMuteMenuItem.click();
      await bob.chat.expectPmConversationMuted(alice.nick, true);

      const stableTitle = await bob.page.title();
      await resetNotificationSpies(bob.page);
      await alice.chat.sendMessage(`/msg ${bob.nick} ${message}`);

      await bob.chat.expectTabSelected('#lobby');
      await bob.chat.expectTabUnread(alice.nick, true);
      await bob.chat.expectPmConversationUnread(alice.nick, true);
      await expect(bob.chat.pmUnreadBadge(alice.nick)).toHaveText('1');
      await bob.chat.expectPmConversationMuted(alice.nick, true);
      await bob.chat.expectMessageHidden(message);
      await expectNoSoundStarts(bob.page);
      await expectNoTitleFlash(bob.page, stableTitle);
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
