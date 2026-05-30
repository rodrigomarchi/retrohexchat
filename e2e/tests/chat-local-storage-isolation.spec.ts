import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function installAudioSpy(ctx: BrowserContext) {
  await ctx.addInitScript(() => {
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

async function newSignedInUser(
  browser: Browser,
  prefix = 'aa8',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  await installAudioSpy(ctx);
  const page = await ctx.newPage();
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

async function resetAudioSpy(page: Page) {
  await page.evaluate(() => {
    (window as unknown as { __soundStartCount: number }).__soundStartCount = 0;
  });
}

async function expectSoundStarts(page: Page, count: number) {
  await expect
    .poll(() =>
      page.evaluate(
        () => (window as unknown as { __soundStartCount: number }).__soundStartCount,
      ),
    )
    .toBe(count);
}

async function expectNoSoundStarts(page: Page) {
  await page.waitForTimeout(500);
  await expectSoundStarts(page, 0);
}

async function expectMuteStorage(page: Page, value: string | null) {
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem('retro_hex_chat_mute')))
    .toBe(value);
}

test.describe('Local browser storage isolation', () => {
  test('mute localStorage survives reload but does not leak across browser contexts (AA8)', async ({
    browser,
  }) => {
    const mutedUser = await newSignedInUser(browser, 'aa8m');
    const isolatedUser = await newSignedInUser(browser, 'aa8i');

    try {
      await expect(mutedUser.chat.statusBarMuteToggle).toHaveAttribute(
        'aria-label',
        'Mute',
      );
      await mutedUser.chat.statusBarMuteToggle.click();
      await expect(mutedUser.chat.statusBarMuteToggle).toHaveAttribute(
        'aria-label',
        'Unmute',
      );
      await expectMuteStorage(mutedUser.page, 'true');

      await mutedUser.page.reload();
      await mutedUser.chat.waitUntilConnected();
      await expect(mutedUser.chat.statusBarMuteToggle).toHaveAttribute(
        'aria-label',
        'Unmute',
      );
      await expectMuteStorage(mutedUser.page, 'true');

      await mutedUser.chat.openSoundSettingsFromMenu();
      await resetAudioSpy(mutedUser.page);
      await mutedUser.chat.soundPreviewButton('message').click();
      await expectNoSoundStarts(mutedUser.page);
      await mutedUser.chat.soundSettingsDialog
        .getByRole('button', { name: 'Cancel' })
        .click();

      await expect(isolatedUser.chat.statusBarMuteToggle).toHaveAttribute(
        'aria-label',
        'Mute',
      );
      await expectMuteStorage(isolatedUser.page, null);

      await isolatedUser.chat.openSoundSettingsFromMenu();
      await resetAudioSpy(isolatedUser.page);
      await isolatedUser.chat.soundPreviewButton('message').click();
      await expectSoundStarts(isolatedUser.page, 1);
    } finally {
      await closeUsers([mutedUser, isolatedUser]);
    }
  });
});
