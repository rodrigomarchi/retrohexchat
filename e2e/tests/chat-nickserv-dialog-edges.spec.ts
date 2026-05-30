import { Browser, BrowserContext, Page, expect, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'nsdlg'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'nsdlg') {
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
  prefix = 'nsdlg',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function registeredNick(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('NickServ dialog edge cases', () => {
  test('registered nick password dialog cancel keeps old nickname and chat input usable (W3)', async ({
    browser,
  }) => {
    const targetNick = uniqueNickname('w3tgt');
    const targetPassword = `pw-${Date.now().toString(36)}`;
    const target = await registeredNick(browser, targetNick, targetPassword);
    const alice = await newSignedInUser(browser, 'w3a');
    const channel = uniqueChannel('nscancel');
    const afterCancelText = `nickserv-cancel-${Date.now()}`;

    try {
      await target.chat.disconnect();

      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.expectNickInList(alice.nick);

      await alice.chat.sendMessage(`/nick ${targetNick}`);
      await expect(alice.chat.nickChangeDialog).toBeVisible();
      await expect(alice.chat.nickChangeDialog).toContainText(targetNick);
      await expect(alice.chat.nickChangePassword).toBeVisible();

      await alice.chat.nickChangeCancelButton.click();
      await expect(alice.chat.nickChangeConfirmButton).toBeHidden();
      await alice.chat.expectNickInList(alice.nick);
      await alice.chat.expectNickNotInList(targetNick);
      await alice.chat.expectTabSelected(channel);

      await alice.chat.sendMessage(afterCancelText);
      await alice.chat.expectMessageVisible(afterCancelText);
      await expect(
        alice.chat.messageNickByText(afterCancelText, alice.nick),
      ).toBeVisible();
    } finally {
      await closeUsers([target, alice]);
    }
  });
});
