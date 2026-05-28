import { test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

test.describe('Send a chat message', () => {
  test('typing a plain message and pressing Enter appends it to the message list (A1)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await connect.registerWithPassword('pass12345');
    await chat.waitUntilConnected();

    const text = `hello-enter-${Date.now()}`;
    await chat.chatInput.fill(text);
    await chat.chatInput.press('Enter');

    await chat.expectMessageVisible(text);
  });

  test('clicking the Send button submits the message (A1b)', async ({ page }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await connect.registerWithPassword('pass12345');
    await chat.waitUntilConnected();

    const text = `hello-button-${Date.now()}`;
    await chat.chatInput.fill(text);
    // The hook flips disabled=false client-side as soon as the input
    // event fires; we wait for that to confirm the button is clickable.
    await expect(chat.chatSendButton).toBeEnabled();
    await chat.chatSendButton.click();

    await chat.expectMessageVisible(text);
    // After submit, @input resets to "" and the hook re-disables.
    await expect(chat.chatInput).toHaveValue('');
    await expect(chat.chatSendButton).toBeDisabled();
  });

  test('Send button reflects textarea content: disabled → enabled → disabled (A2)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await connect.registerWithPassword('pass12345');
    await chat.waitUntilConnected();

    // Empty input on arrival.
    await expect(chat.chatInput).toHaveValue('');
    await expect(chat.chatSendButton).toBeDisabled();

    // Typing enables.
    await chat.chatInput.fill('hello');
    await expect(chat.chatSendButton).toBeEnabled();

    // Clearing disables again.
    await chat.chatInput.fill('');
    await expect(chat.chatSendButton).toBeDisabled();
  });

  test('character counter shows <chars>/1000 as the user types (A3)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await connect.registerWithPassword('pass12345');
    await chat.waitUntilConnected();

    await expect(chat.charCounter).toContainText('0/1000');
    await chat.chatInput.fill('hello');
    await expect(chat.charCounter).toContainText('5/1000');
  });
});
