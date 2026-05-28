import { Browser, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'list'): string {
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

async function setupListedChannel(browser: Browser, channel: string) {
  const ownerContext = await browser.newContext();
  const joinerContext = await browser.newContext();
  const ownerPage = await ownerContext.newPage();
  const joinerPage = await joinerContext.newPage();

  const owner = await signedInUser(ownerPage, 'owner');
  const joiner = await signedInUser(joinerPage, 'joiner');

  await owner.chat.sendMessage(`/join ${channel}`);
  await owner.chat.expectTabVisible(channel);

  return {
    ownerContext,
    joinerContext,
    joinerChat: joiner.chat,
  };
}

test.describe('Channel list dialog', () => {
  test('/list filters a unique channel and joins it through the Join button (H8)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('listed');
    const { ownerContext, joinerContext, joinerChat } = await setupListedChannel(
      browser,
      channel,
    );

    try {
      await joinerChat.sendMessage('/list');

      await expect(joinerChat.channelListSearch).toBeVisible();
      await expect(joinerChat.channelListJoinButton).toBeDisabled();

      await joinerChat.channelListSearch.fill(channel.slice(1));
      await expect(joinerChat.channelListRow(channel)).toBeVisible();

      await joinerChat.channelListRow(channel).click();
      await expect(joinerChat.channelListJoinButton).toBeEnabled();
      await joinerChat.channelListJoinButton.click();

      await joinerChat.expectTabVisible(channel);
      await expect(joinerChat.channelListSearch).toBeHidden();
    } finally {
      await ownerContext.close();
      await joinerContext.close();
    }
  });
});
