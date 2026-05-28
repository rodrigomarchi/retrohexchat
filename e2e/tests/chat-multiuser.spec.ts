import { test, expect, Browser } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

// Common setup for two-user multi-context specs in Group B. Both users
// register fresh nicks and land on the default #lobby channel.
async function setupTwoUsers(browser: Browser) {
  const ctxA = await browser.newContext();
  const ctxB = await browser.newContext();
  const pageA = await ctxA.newPage();
  const pageB = await ctxB.newPage();
  const nickA = uniqueNickname('a');
  const nickB = uniqueNickname('b');
  const pw = 'pass12345';

  const connA = new ConnectPage(pageA);
  const chatA = new ChatPage(pageA);
  await connA.open();
  await connA.enterNickname(nickA);
  await connA.registerWithPassword(pw);
  await chatA.waitUntilConnected();

  const connB = new ConnectPage(pageB);
  const chatB = new ChatPage(pageB);
  await connB.open();
  await connB.enterNickname(nickB);
  await connB.registerWithPassword(pw);
  await chatB.waitUntilConnected();

  return { ctxA, ctxB, pageA, pageB, chatA, chatB, nickA, nickB };
}

test.describe('Multi-user real-time chat', () => {
  test('A sends a message → B sees it in real time in #lobby (B1)', async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, chatB } = await setupTwoUsers(browser);
    try {
      const text = `multi-user msg ${Date.now()}`;
      await chatA.sendMessage(text);
      await chatB.expectMessageVisible(text);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test('B joining #lobby → A sees a "has joined the channel" system message (B2)', async ({
    browser,
  }) => {
    // For B2 we want A to be in the channel BEFORE B connects, so we
    // can't reuse setupTwoUsers which connects them together.
    const ctxA = await browser.newContext();
    const ctxB = await browser.newContext();
    const pageA = await ctxA.newPage();
    const pageB = await ctxB.newPage();
    try {
      const connA = new ConnectPage(pageA);
      const chatA = new ChatPage(pageA);
      await connA.open();
      await connA.enterNickname(uniqueNickname('a'));
      await connA.registerWithPassword('pass12345');
      await chatA.waitUntilConnected();

      const nickB = uniqueNickname('b');
      const connB = new ConnectPage(pageB);
      const chatB = new ChatPage(pageB);
      await connB.open();
      await connB.enterNickname(nickB);
      await connB.registerWithPassword('pass12345');
      await chatB.waitUntilConnected();

      // pubsub_handlers/membership emits "<nick> has joined the channel"
      // into every #lobby subscriber's view.
      await chatA.expectMessageVisible(`${nickB} has joined the channel`);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test('B disconnects → A sees a "has left" system message (B3)', async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, chatB, nickB } = await setupTwoUsers(browser);
    try {
      await chatB.disconnect();
      // confirm_disconnect calls cleanup_channels with reason "Leaving",
      // which broadcasts a user_left event picked up by A's #lobby.
      await chatA.expectMessageVisible(`${nickB} has left`);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test("B joining → A's nicklist shows B as a channel member (B4)", async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, nickB } = await setupTwoUsers(browser);
    try {
      await chatA.expectNickInList(nickB);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
