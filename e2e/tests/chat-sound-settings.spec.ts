import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

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

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname('sound');
  const password = 'pass12345';

  await installAudioSpy(page);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, nick, password };
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

async function expectClientMuteState(page: Page, muted: boolean) {
  await expect
    .poll(() =>
      page.evaluate(() => localStorage.getItem('retro_hex_chat_mute')),
    )
    .toBe(muted.toString());
}

test.describe('Sound settings dialog', () => {
  test('OK, Apply, Cancel, and Preview persist only intended sound settings (U3)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);

    await chat.openSoundSettingsFromMenu();
    await chat.expectSoundSelected('message', 'Ding Low');
    await expect(chat.soundFlashToggle('message')).not.toBeChecked();

    await chat.selectSound('message', 'Beep');
    await resetAudioSpy(page);
    await chat.soundPreviewButton('message').click();
    await expectSoundStarts(page, 1);
    await expect(chat.soundSettingsDialog).toBeVisible();

    await chat.soundSettingsDialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(chat.soundSettingsDialog).toBeHidden();

    await chat.openSoundSettingsFromMenu();
    await chat.expectSoundSelected('message', 'Ding Low');
    await expect(chat.soundFlashToggle('message')).not.toBeChecked();

    await chat.selectSound('message', 'Beep');
    await chat.soundFlashToggle('message').click();
    await expect(chat.soundFlashToggle('message')).toBeChecked();
    await chat.soundSettingsDialog.getByRole('button', { name: 'Apply' }).click();
    await expect(chat.soundSettingsDialog).toBeVisible();

    await chat.soundSettingsDialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(chat.soundSettingsDialog).toBeHidden();

    await chat.openSoundSettingsFromMenu();
    await chat.expectSoundSelected('message', 'Beep');
    await expect(chat.soundFlashToggle('message')).toBeChecked();

    await chat.selectSound('message', 'Alert');
    await chat.soundFlashToggle('message').click();
    await expect(chat.soundFlashToggle('message')).not.toBeChecked();
    await chat.soundSettingsDialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(chat.soundSettingsDialog).toBeHidden();

    await chat.openSoundSettingsFromMenu();
    await chat.expectSoundSelected('message', 'Beep');
    await expect(chat.soundFlashToggle('message')).toBeChecked();

    await chat.selectSound('message', 'Chime Long');
    await chat.soundSettingsDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.soundSettingsDialog).toBeHidden();

    await chat.openSoundSettingsFromMenu();
    await chat.expectSoundSelected('message', 'Chime Long');
    await expect(chat.soundFlashToggle('message')).toBeChecked();
  });

  test('mute state stays synced through rerenders, Sound Settings preview, and reconnect (U4)', async ({
    page,
  }) => {
    const { chat, nick, password } = await signedInUser(page);
    const rerenderMessage = `sound mute rerender ${Date.now()}`;
    const connect = new ConnectPage(page);

    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      'aria-label',
      'Mute',
    );

    await chat.statusBarMuteToggle.click();
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      'aria-label',
      'Unmute',
    );
    await expectClientMuteState(page, true);

    await chat.openSoundSettingsFromMenu();
    await resetAudioSpy(page);
    await chat.soundPreviewButton('message').click();
    await expectNoSoundStarts(page);

    await chat.soundSettingsDialog.getByRole('button', { name: 'Apply' }).click();
    await expect(chat.soundSettingsDialog).toBeVisible();
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      'aria-label',
      'Unmute',
    );
    await resetAudioSpy(page);
    await chat.soundPreviewButton('message').click();
    await expectNoSoundStarts(page);

    await chat.soundSettingsDialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(chat.soundSettingsDialog).toBeHidden();
    await chat.sendMessage(rerenderMessage);
    await chat.expectMessageVisible(rerenderMessage);
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      'aria-label',
      'Unmute',
    );
    await expectClientMuteState(page, true);

    await chat.disconnect();
    await connect.open();
    await connect.enterNickname(nick);
    await connect.authenticateWithPassword(password);
    await chat.waitUntilConnected();
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      'aria-label',
      'Unmute',
    );
    await expectClientMuteState(page, true);

    await chat.openSoundSettingsFromMenu();
    await resetAudioSpy(page);
    await chat.soundPreviewButton('message').click();
    await expectNoSoundStarts(page);

    await chat.soundSettingsDialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(chat.soundSettingsDialog).toBeHidden();
    await chat.statusBarMuteToggle.click();
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      'aria-label',
      'Mute',
    );
    await expectClientMuteState(page, false);

    await chat.openSoundSettingsFromMenu();
    await resetAudioSpy(page);
    await chat.soundPreviewButton('message').click();
    await expectSoundStarts(page, 1);
  });
});
