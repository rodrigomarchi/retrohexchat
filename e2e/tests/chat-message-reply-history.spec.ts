import { Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'rplhist'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'rplhist') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function sendPasteLines(chat: ChatPage, lines: string[]) {
  await chat.pasteText(lines.join('\n'));
  await expect(chat.pasteConfirmSendButton).toBeVisible();
  await chat.pasteConfirmSendButton.click();
  await expect(chat.pasteConfirmSendButton).toBeHidden();
}

test.describe('Reply history edge cases', () => {
  test('clicking a reply parent link reports when the parent is only in older history (S6)', async ({
    page,
  }) => {
    test.setTimeout(90_000);

    const { chat } = await signedInUser(page, 'rphis');
    const channel = uniqueChannel();
    const marker = Date.now();
    const parent = `reply-history-parent-${marker}`;
    const reply = `reply-history-child-${marker}`;
    const fillerLines = Array.from(
      { length: 55 },
      (_, index) => `reply-history-filler-${marker}-${String(index + 1).padStart(2, '0')}`,
    );

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage(parent);
    await chat.expectMessageVisible(parent);

    await sendPasteLines(chat, fillerLines);
    await chat.expectMessageVisible(fillerLines.at(-1)!, 35_000);

    await chat.openMessageContextMenu(parent);
    await chat.contextReplyMenuItem.click();
    await expect(chat.replyBar).toBeVisible();

    await chat.sendMessage(reply);
    await chat.expectMessageVisible(reply);

    await chat.switchToTab('#lobby');
    await chat.switchToTab(channel);

    const replyBlock = chat.messageRowByText(reply).getByTestId('reply-block');
    await expect(replyBlock).toBeVisible();
    await expect(replyBlock).toContainText(parent);

    await replyBlock.click();

    await chat.expectMessageVisible('Reply parent message is not currently loaded');
  });
});
