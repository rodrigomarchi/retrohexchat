import { test, expect, Browser } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

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

  return { ctxA, ctxB, chatA, chatB, nickA, nickB };
}

test.describe('Private messages', () => {
  test('/msg <bob> hi opens a PM tab and sends the message (D1)', async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, nickB } = await setupTwoUsers(browser);
    try {
      const text = `pm-hello-${Date.now()}`;
      await chatA.sendMessage(`/msg ${nickB} ${text}`);

      // A new PM tab labeled with bob's nick appears on A's side.
      // By design, /msg does NOT auto-switch the sender's focus (yanking
      // the view away while typing would be disruptive UX). The user has
      // to click the tab to read what they just sent.
      await chatA.expectTabVisible(nickB);
      await chatA.switchToTab(nickB);
      await chatA.expectMessageVisible(text);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test('recipient sees the PM in a new tab labeled with the sender nick (D2)', async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, chatB, nickA, nickB } = await setupTwoUsers(browser);
    try {
      const text = `pm-incoming-${Date.now()}`;
      await chatA.sendMessage(`/msg ${nickB} ${text}`);

      // Bob's tablist now includes a PM tab with alice's nick.
      await chatB.expectTabVisible(nickA);
      await chatB.switchToTab(nickA);
      await chatB.expectMessageVisible(text);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test('reply from B updates A’s PM tab with the response (D3)', async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, chatB, nickA, nickB } = await setupTwoUsers(browser);
    try {
      const greeting = `pm-greet-${Date.now()}`;
      const reply = `pm-reply-${Date.now()}`;

      await chatA.sendMessage(`/msg ${nickB} ${greeting}`);
      await chatB.expectTabVisible(nickA);
      await chatB.switchToTab(nickA);

      // Once Bob is on the PM tab, sending a regular message goes to
      // the active conversation (the PM with A).
      await chatB.sendMessage(reply);

      // A's PM tab with B should pick up the reply (A may still have
      // the PM tab as active from D1's flow, but switching is idempotent
      // and makes the spec robust).
      await chatA.switchToTab(nickB);
      await chatA.expectMessageVisible(reply);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test('closing the PM tab removes it from the tablist (D4)', async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, nickB } = await setupTwoUsers(browser);
    try {
      await chatA.sendMessage(`/msg ${nickB} ping`);
      await chatA.expectTabVisible(nickB);

      await chatA.closeTab(nickB);
      await chatA.expectTabHidden(nickB);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
