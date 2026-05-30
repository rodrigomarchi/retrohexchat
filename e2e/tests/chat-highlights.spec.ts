import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx?: BrowserContext;
  nick: string;
};

function uniqueHighlightWord(): string {
  return `spark${Date.now().toString(36)}${Math.random()
    .toString(36)
    .slice(2, 5)}`;
}

async function signedInUser(page: Page, prefix = 'hl') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = 'hl',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { ...user, ctx };
}

test.describe('Highlight words dialog', () => {
  test('adds, edits, removes a word and highlights matching inbound messages (U1)', async ({
    browser,
    page,
  }) => {
    const alice = await signedInUser(page, 'hla');
    const bob = await newSignedInUser(browser, 'hlb');
    const word = uniqueHighlightWord();
    const highlightedText = `please notice ${word} from another user`;
    const plainText = `after remove ${word} should be plain`;

    try {
      await alice.chat.openHighlightDialogFromMenu();

      await alice.chat.addHighlightWord(word, 4);
      await expect(alice.chat.highlightWordColor(word)).toHaveClass(/irc-bg-4/);

      await alice.chat.editHighlightWordColor(word, 9);
      await expect(alice.chat.highlightWordColor(word)).toHaveClass(/irc-bg-9/);

      await alice.chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
      await expect(alice.chat.highlightDialog).toBeHidden();

      await bob.chat.sendMessage(highlightedText);
      const highlightedRow = alice.chat.messageRowByText(highlightedText);
      await expect(highlightedRow).toBeVisible({ timeout: 10_000 });
      await expect(highlightedRow).toHaveAttribute(
        'data-testid',
        'highlighted-message',
      );
      await expect(highlightedRow).toHaveClass(/chat-message--highlighted/);
      await expect(highlightedRow).toHaveClass(/irc-bg-9/);

      await alice.chat.openHighlightDialogFromMenu();
      await alice.chat.removeHighlightWord(word);
      await alice.chat.highlightDialog.getByRole('button', { name: 'OK' }).click();
      await expect(alice.chat.highlightDialog).toBeHidden();

      await bob.chat.sendMessage(plainText);
      const plainRow = alice.chat.messageRowByText(plainText);
      await expect(plainRow).toBeVisible({ timeout: 10_000 });
      await expect(plainRow).not.toHaveClass(/chat-message--highlighted/);
      await expect(plainRow).not.toHaveClass(/irc-bg-9/);
    } finally {
      await bob.ctx?.close();
    }
  });
});
