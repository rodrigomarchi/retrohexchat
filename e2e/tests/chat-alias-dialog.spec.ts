import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueAlias(prefix = 'dlg'): string {
  return `${prefix}${Math.random().toString(36).slice(2, 8)}`;
}

async function signedInUser(page: Page, prefix = 'e2e') {
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
  prefix = 'e2e',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Alias dialog', () => {
  test('/alias opens Alias Editor; dialog add/edit/remove mirrors slash behavior (L5)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'aldg');
    const alias = uniqueAlias();
    const firstText = `alias-dialog-first-${Date.now()}`;
    const editedText = `alias-dialog-edited-${Date.now()}`;

    try {
      await user.chat.sendMessage('/alias');
      await expect(user.chat.aliasDialog).toBeVisible();

      await user.chat.addAliasFromDialog(alias, `/me ${firstText}`);
      await user.chat.closeAliasEditor();

      await user.chat.sendMessage(`/${alias}`);
      await user.chat.expectMessageVisible(firstText);

      await user.chat.openAliasEditorFromMenu();
      await user.chat.editAliasFromDialog(alias, `/me ${editedText}`);
      await user.chat.closeAliasEditor();

      await user.chat.sendMessage('/clear');
      await user.chat.sendMessage(`/${alias}`);
      await user.chat.expectMessageVisible(editedText);

      await user.chat.openAliasEditorFromMenu();
      await user.chat.removeAliasFromDialog(alias);
      await user.chat.closeAliasEditor();

      await user.chat.sendMessage('/clear');
      await user.chat.sendMessage('/alias list');
      await user.chat.expectMessageVisible('Your alias list is empty');
    } finally {
      await closeUsers([user]);
    }
  });
});
