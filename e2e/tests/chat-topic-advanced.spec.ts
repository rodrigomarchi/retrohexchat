import { Browser, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'topic'): string {
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

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const ctxA = await browser.newContext();
  const ctxB = await browser.newContext();
  const pageA = await ctxA.newPage();
  const pageB = await ctxB.newPage();

  const userA = await signedInUser(pageA, 'a');
  const userB = await signedInUser(pageB, 'b');

  await userA.chat.sendMessage(`/join ${channel}`);
  await userB.chat.sendMessage(`/join ${channel}`);
  await userA.chat.expectNickInList(userB.nick);
  await userB.chat.expectNickInList(userA.nick);

  return {
    ctxA,
    ctxB,
    chatA: userA.chat,
    chatB: userB.chat,
  };
}

test.describe('Topic command advanced flows', () => {
  test('/topic with no args prints the current topic (H6)', async ({ page }) => {
    const { chat } = await signedInUser(page);
    const channel = uniqueChannel('topicview');
    const topic = `Current topic ${Date.now()}`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.sendMessage(`/topic ${topic}`);
    await chat.expectMessageVisible(`changed the topic to: ${topic}`);

    await chat.sendMessage('/topic');

    await chat.expectMessageVisible(`Topic for ${channel}: ${topic}`);
  });

  test('topic changes are visible in realtime to another channel member (H7)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('topicrt');
    const topic = `Realtime topic ${Date.now()}`;
    const { ctxA, ctxB, chatA, chatB } = await setupTwoUsersInChannel(
      browser,
      channel,
    );

    try {
      await chatA.sendMessage(`/topic ${topic}`);

      await chatA.expectMessageVisible(`changed the topic to: ${topic}`);
      await chatB.expectMessageVisible(`changed the topic to: ${topic}`);
      await chatB.topicBar.getByText(topic).waitFor();
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
