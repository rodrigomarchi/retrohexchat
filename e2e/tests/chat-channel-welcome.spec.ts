import { Browser, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'welcome'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: import('@playwright/test').Page,
  prefix = 'e2e',
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return { chat, nick };
}

async function setupOwnerAndJoiner(browser: Browser) {
  const ownerContext = await browser.newContext();
  const joinerContext = await browser.newContext();
  const ownerPage = await ownerContext.newPage();
  const joinerPage = await joinerContext.newPage();

  const owner = await signedInUser(ownerPage, 'owner');
  const joiner = await signedInUser(joinerPage, 'joiner');

  return {
    ownerContext,
    joinerContext,
    ownerChat: owner.chat,
    joinerChat: joiner.chat,
  };
}

test.describe('Channel welcome messages', () => {
  test('/setwelcome shows a channel welcome once per joiner session (H9)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('welcome');
    const welcome = `Welcome once ${Date.now()}`;
    const { ownerContext, joinerContext, ownerChat, joinerChat } =
      await setupOwnerAndJoiner(browser);

    try {
      await ownerChat.sendMessage(`/join ${channel}`);
      await ownerChat.expectTabVisible(channel);
      await ownerChat.sendMessage(`/setwelcome ${welcome}`);
      await ownerChat.expectMessageVisible(
        `Welcome message for ${channel} has been set.`,
      );

      await joinerChat.sendMessage(`/join ${channel}`);
      await joinerChat.expectTabVisible(channel);
      await joinerChat.expectMessageVisible(`[Welcome] ${welcome}`);
      const welcomeMessages = joinerChat.messageList
        .locator('[data-message-id]')
        .filter({ hasText: `[Welcome] ${welcome}` });
      await expect(welcomeMessages).toHaveCount(1);

      await joinerChat.sendMessage(`/part ${channel}`);
      await joinerChat.expectTabHidden(channel);
      await joinerChat.sendMessage(`/join ${channel}`);
      await joinerChat.expectTabVisible(channel);
      await expect(welcomeMessages).toHaveCount(1);
    } finally {
      await ownerContext.close();
      await joinerContext.close();
    }
  });

  test('/clearwelcome stops the channel welcome for later joiners (H10)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('clearwelcome');
    const welcome = `Cleared welcome ${Date.now()}`;
    const { ownerContext, joinerContext, ownerChat, joinerChat } =
      await setupOwnerAndJoiner(browser);

    try {
      await ownerChat.sendMessage(`/join ${channel}`);
      await ownerChat.expectTabVisible(channel);
      await ownerChat.sendMessage(`/setwelcome ${welcome}`);
      await ownerChat.expectMessageVisible(
        `Welcome message for ${channel} has been set.`,
      );

      await ownerChat.sendMessage('/clearwelcome');
      await ownerChat.expectMessageVisible(
        `Welcome message for ${channel} has been cleared.`,
      );

      await joinerChat.sendMessage(`/join ${channel}`);
      await joinerChat.expectTabVisible(channel);
      await joinerChat.expectMessageHidden(`[Welcome] ${welcome}`);
    } finally {
      await ownerContext.close();
      await joinerContext.close();
    }
  });
});
