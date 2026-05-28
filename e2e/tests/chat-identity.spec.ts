import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

test.describe('Identity and status commands', () => {
  test('/nick <new> opens the change dialog and switches nickname (E1)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    const oldNick = uniqueNickname('a');
    await connect.open();
    await connect.enterNickname(oldNick);
    await connect.registerWithPassword('pass12345');
    await chat.waitUntilConnected();

    // Confirm the user is in the channel under the original nick.
    await chat.expectNickInList(oldNick);

    // Pick a brand-new (unregistered) target nick. The dialog for an
    // unregistered target shows no password field; just confirm.
    const newNick = uniqueNickname('b');
    await chat.sendMessage(`/nick ${newNick}`);

    const dialog = page.getByTestId('nick-change-dialog');
    await expect(dialog).toBeVisible();
    await expect(dialog).toContainText(newNick);

    await page.getByTestId('nick-change-confirm').click();

    // After the dialog confirms, the JS hook submits the hidden form to
    // /chat/session with the new nick; the LiveView re-mounts. The new
    // nick should appear in our own nicklist; the old one should be gone.
    await expect(chat.nicklistItem(newNick)).toBeVisible();
    await expect(chat.nicklistItem(oldNick)).toHaveCount(0);
  });

  test('/away <msg> then /away toggles the away status messages (E2)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await connect.registerWithPassword('pass12345');
    await chat.waitUntilConnected();

    const awayMsg = `at-lunch-${Date.now()}`;
    await chat.sendMessage(`/away ${awayMsg}`);
    // The set_away ui_action emits a system_event "You are now away: X"
    // into the active channel/status stream.
    await chat.expectMessageVisible(`You are now away: ${awayMsg}`);

    // Clearing flips the system message.
    await chat.sendMessage('/away');
    await chat.expectMessageVisible('You are no longer away');
  });
});
