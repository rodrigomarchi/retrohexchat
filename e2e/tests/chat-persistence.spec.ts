import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type ChatUser = {
  context: BrowserContext;
  page: Page;
  connect: ConnectPage;
  chat: ChatPage;
  nick: string;
  password: string;
};

async function createRegisteredUser(
  browser: Browser,
  prefix: string,
): Promise<ChatUser> {
  const context = await browser.newContext();
  const page = await context.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  const password = 'pass12345';

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { context, page, connect, chat, nick, password };
}

async function expectTabBefore(chat: ChatPage, left: string, right: string) {
  const leftTab = chat.tab(left);
  const rightTab = chat.tab(right);

  await expect(leftTab).toBeVisible();
  await expect(rightTab).toBeVisible();

  const leftBox = await leftTab.boundingBox();
  const rightBox = await rightTab.boundingBox();

  expect(leftBox).not.toBeNull();
  expect(rightBox).not.toBeNull();
  expect(leftBox!.x).toBeLessThan(rightBox!.x);
}

test.describe('Chat persistence', () => {
  test('registered PM partners restore on reconnect ordered by recency (P1)', async ({
    browser,
  }) => {
    const alice = await createRegisteredUser(browser, 'pma');
    const bob = await createRegisteredUser(browser, 'pmb');
    const carol = await createRegisteredUser(browser, 'pmc');

    try {
      const bobMessage = `persist bob ${Date.now()}`;
      const carolMessage = `persist carol ${Date.now()}`;

      await alice.chat.sendMessage(`/msg ${bob.nick} ${bobMessage}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.page.waitForTimeout(100);
      await alice.chat.sendMessage(`/msg ${carol.nick} ${carolMessage}`);
      await alice.chat.expectTabVisible(carol.nick);

      await alice.chat.disconnect();
      await alice.connect.open();
      await alice.connect.enterNickname(alice.nick);
      await alice.connect.authenticateWithPassword(alice.password);
      await alice.chat.waitUntilConnected();

      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.expectTabVisible(carol.nick);
      await expectTabBefore(alice.chat, carol.nick, bob.nick);

      await alice.chat.switchToTab(carol.nick);
      await alice.chat.expectMessageVisible(carolMessage);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageVisible(bobMessage);
    } finally {
      await alice.context.close();
      await bob.context.close();
      await carol.context.close();
    }
  });

  test('guest PM partners do not restore after reconnect (P2)', async ({
    browser,
  }) => {
    const alice = await createRegisteredUser(browser, 'pga');
    const bob = await createRegisteredUser(browser, 'pgb');

    try {
      const guestNick = uniqueNickname('pgg');
      const guestMessage = `guest pm ${Date.now()}`;

      await alice.chat.sendMessage(`/nick ${guestNick}`);
      await expect(alice.page.getByTestId('nick-change-dialog')).toBeVisible();
      await alice.page.getByTestId('nick-change-confirm').click();
      await alice.chat.waitUntilConnected();
      await expect(alice.chat.nicklistItem(guestNick)).toBeVisible();

      await alice.chat.sendMessage(`/msg ${bob.nick} ${guestMessage}`);
      await alice.chat.expectTabVisible(bob.nick);

      await alice.page.reload();
      await alice.chat.waitUntilConnected();

      await alice.chat.expectTabHidden(bob.nick);
    } finally {
      await alice.context.close();
      await bob.context.close();
    }
  });
});
