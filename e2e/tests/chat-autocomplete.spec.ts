import { test, Browser } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: import('@playwright/test').Page, prefix = 'e2e') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return { chat, nick };
}

async function setupTwoUsers(browser: Browser) {
  const ctxA = await browser.newContext();
  const ctxB = await browser.newContext();
  const pageA = await ctxA.newPage();
  const pageB = await ctxB.newPage();

  const userA = await signedInUser(pageA, 'a');
  const userB = await signedInUser(pageB, 'b');

  return {
    ctxA,
    ctxB,
    chatA: userA.chat,
    chatB: userB.chat,
    nickA: userA.nick,
    nickB: userB.nick,
  };
}

test.describe('Autocomplete', () => {
  test('typing @ plus a nick prefix shows matching channel nicks (F3)', async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, nickB } = await setupTwoUsers(browser);
    try {
      await chatA.switchToTab('#lobby');
      await chatA.expectNickInList(nickB);

      await chatA.chatInput.click();
      await chatA.chatInput.pressSequentially(`@${nickB.slice(0, 3)}`);

      await chatA.expectAutocompleteContains(nickB);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test('typing /jo shows command autocomplete suggestions (F4)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);

    await chat.chatInput.click();
    await chat.chatInput.pressSequentially('/jo');

    await chat.expectAutocompleteContains('/join');
    await chat.expectAutocompleteContains('/autojoin');
  });
});
