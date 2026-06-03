import { expect, Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueTimer(prefix = 'tm'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signedInUser(page: Page, prefix = 'tm') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat };
}

async function expectNoActiveTimers(chat: ChatPage) {
  await expect(async () => {
    await chat.sendMessage('/timer list');
    await chat.expectMessageVisible('No active timers.', 1_000);
  }).toPass({ timeout: 7_000 });
}

test.describe('Timer commands', () => {
  test('/timer one-shot fires once, then disappears from list (L15)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'tmra');
    const timerName = uniqueTimer('once');
    const timerText = `timer-once-${Date.now()}`;

    await chat.sendMessage(`/timer ${timerName} 1 /me ${timerText}`);
    await chat.expectMessageVisible(
      `* Timer '${timerName}' set: one-shot, 1s`,
    );

    await chat.sendMessage('/clear');
    await chat.expectMessageVisible(timerText, 5_000);

    await expectNoActiveTimers(chat);
  });

  test('/timer stop cancels before firing; missing timer shows error (L16)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'tmrb');
    const timerName = uniqueTimer('stop');
    const timerText = `timer-cancelled-${Date.now()}`;

    await chat.sendMessage(`/timer ${timerName} 2 /me ${timerText}`);
    await chat.expectMessageVisible(
      `* Timer '${timerName}' set: one-shot, 2s`,
    );

    await chat.sendMessage(`/timer stop ${timerName}`);
    await chat.expectMessageVisible(`* Timer '${timerName}' stopped`);

    await chat.sendMessage('/clear');
    await page.waitForTimeout(2_500);
    await chat.expectMessageHidden(timerText);

    await chat.sendMessage('/timer stop missingtimer');
    await chat.expectMessageVisible("Timer 'missingtimer' not found");
  });

  test('repeating timer below minimum is clamped and can be stopped (L17)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'tmrc');
    const timerName = uniqueTimer('rep');
    const timerText = `timer-repeat-${Date.now()}`;

    await chat.sendMessage(`/timer ${timerName} repeat 1 /me ${timerText}`);
    await chat.expectMessageVisible(
      '* Repeat interval clamped to minimum 10 seconds.',
    );
    await chat.expectMessageVisible(`* Timer '${timerName}' set: repeat, 10s`);

    await chat.sendMessage(`/timer stop ${timerName}`);
    await chat.expectMessageVisible(`* Timer '${timerName}' stopped`);

    await chat.sendMessage('/clear');
    await expectNoActiveTimers(chat);
  });
});
