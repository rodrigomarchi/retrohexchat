import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'e2e'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signedInUser(page: import('@playwright/test').Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname());
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return chat;
}

test.describe('Channels and navigation', () => {
  test('/join #room creates a new tab and switches to it (C1)', async ({ page }) => {
    const chat = await signedInUser(page);
    const room = uniqueChannel();

    await chat.sendMessage(`/join ${room}`);
    await chat.expectTabVisible(room);
    await expect(chat.tab(room)).toHaveAttribute('aria-selected', 'true');
  });

  test('switching tabs preserves the channel message history (C2)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    // Drop a marker message into the #lobby tab.
    const marker = `tab-switch-${Date.now()}`;
    await chat.sendMessage(marker);
    await chat.expectMessageVisible(marker);

    // Bounce to Status and back; the marker should still be there.
    await chat.switchToStatusTab();
    await chat.switchToTab('#lobby');
    await chat.expectMessageVisible(marker);
  });

  test('clicking the close button on a channel tab removes it (C3)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const room = uniqueChannel();

    await chat.sendMessage(`/join ${room}`);
    await chat.expectTabVisible(room);

    await chat.closeTab(room);
    await chat.expectTabHidden(room);
  });

  test('/part #room leaves the channel and removes the tab (C4)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const room = uniqueChannel();

    await chat.sendMessage(`/join ${room}`);
    await chat.expectTabVisible(room);

    await chat.sendMessage(`/part ${room}`);
    await chat.expectTabHidden(room);
  });

  test('/topic <text> updates the visible topic bar (C5)', async ({ page }) => {
    const chat = await signedInUser(page);
    const room = uniqueChannel();

    await chat.sendMessage(`/join ${room}`);
    await chat.expectTabVisible(room);

    // Default empty topic shows "No topic set".
    await expect(chat.topicBar).toContainText('No topic set');

    const topic = `e2e topic ${Date.now()}`;
    await chat.sendMessage(`/topic ${topic}`);
    await expect(chat.topicBar).toContainText(topic);
  });
});
