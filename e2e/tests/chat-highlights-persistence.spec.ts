import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueHighlightWord(prefix = 'persist'): string {
  return `${prefix}${Date.now().toString(36)}${Math.random()
    .toString(36)
    .slice(2, 5)}`;
}

async function signedInUser(
  page: Page,
  prefix = 'hlp',
  password = 'pass12345',
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, nick, password };
}

async function reconnectRegisteredUser(
  page: Page,
  chat: ChatPage,
  nick: string,
  password: string,
) {
  const connect = new ConnectPage(page);

  await chat.disconnect();
  await connect.open();
  await connect.enterNickname(nick);
  await connect.authenticateWithPassword(password);
  await chat.waitUntilConnected();
}

async function becomeGuest(page: Page, chat: ChatPage, guestNick: string) {
  await chat.sendMessage(`/nick ${guestNick}`);
  await expect(page.getByTestId('nick-change-dialog')).toBeVisible();
  await page.getByTestId('nick-change-confirm').click();
  await chat.waitUntilConnected();
  await expect(chat.nicklistItem(guestNick)).toBeVisible();
}

test.describe('Highlight words persistence', () => {
  test('registered highlight settings persist across reconnect (U2)', async ({
    page,
  }) => {
    const { chat, nick, password } = await signedInUser(page, 'hlpr');
    const word = uniqueHighlightWord('reg');

    await chat.openHighlightDialogFromMenu();
    await chat.addHighlightWord(word, 6);
    await expect(chat.highlightWordColor(word)).toHaveClass(/irc-bg-6/);
    await chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.highlightDialog).toBeHidden();

    await page.waitForTimeout(750);
    await reconnectRegisteredUser(page, chat, nick, password);

    await chat.openHighlightDialogFromMenu();
    await expect(chat.highlightWordRow(word)).toBeVisible();
    await expect(chat.highlightWordColor(word)).toHaveClass(/irc-bg-6/);
  });

  test('guest highlight settings are session-only after reload (U2)', async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, 'hlpg');
    const guestNick = uniqueNickname('hlpg');
    const word = uniqueHighlightWord('guest');

    await becomeGuest(page, chat, guestNick);

    await chat.openHighlightDialogFromMenu();
    await chat.addHighlightWord(word, 11);
    await expect(chat.highlightWordColor(word)).toHaveClass(/irc-bg-11/);
    await chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
    await expect(chat.highlightDialog).toBeHidden();

    await page.reload();
    await chat.waitUntilConnected();

    await chat.openHighlightDialogFromMenu();
    await expect(chat.highlightWordRow(word)).toHaveCount(0);
  });
});
