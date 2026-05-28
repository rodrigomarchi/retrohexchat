import { Browser, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

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
    nickB: userB.nick,
  };
}

test.describe('Advanced autocomplete', () => {
  test('supported subcommand commands show subcommand suggestions (G6)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);

    for (const [command, suggestion] of [
      ['ns', 'register'],
      ['cs', 'register'],
      ['perform', 'add'],
      ['autojoin', 'add'],
    ]) {
      await chat.chatInput.fill('');
      await chat.chatInput.pressSequentially(`/${command} `);

      await chat.expectAutocompleteContains(suggestion);

      await chat.chatInput.press('Escape');
      await expect(chat.autocompleteDropdown).toHaveCount(0);
    }
  });

  test('selecting /msg command autocomplete enables nick argument autocomplete (G7)', async ({
    browser,
  }) => {
    const { ctxA, ctxB, chatA, nickB } = await setupTwoUsers(browser);
    try {
      await chatA.switchToTab('#lobby');
      await chatA.expectNickInList(nickB);

      await chatA.chatInput.click();
      await chatA.chatInput.pressSequentially('/ms');
      await chatA.expectAutocompleteContains('/msg');

      await chatA.autocompleteItemByText('/msg').click();
      await expect(chatA.chatInput).toHaveValue('/msg ');

      await chatA.chatInput.click();
      await chatA.chatInput.pressSequentially(nickB.slice(0, 3));

      await chatA.expectAutocompleteContains(nickB);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test('autocomplete ArrowUp ArrowDown and Tab navigation does not send a message (G8)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);

    await chat.chatInput.click();
    await chat.chatInput.pressSequentially('/jo');
    await chat.expectAutocompleteContains('/join');

    await chat.chatInput.press('ArrowDown');
    await chat.chatInput.press('ArrowUp');
    await chat.chatInput.press('Tab');

    await expect(chat.chatInput).toHaveValue('/join ');
    await chat.expectMessageHidden('Usage: /join');
    await chat.expectMessageHidden('Unknown command');
  });
});
