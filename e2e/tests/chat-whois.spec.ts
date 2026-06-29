import { Browser, BrowserContext, Page, test, expect } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = 'whois'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
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

async function setupTwoUsersInChannel(browser: Browser, channel: string) {
  const alice = await newSignedInUser(browser, 'wisa');
  const bob = await newSignedInUser(browser, 'wisb');

  await alice.chat.sendMessage(`/join ${channel}`);
  await alice.chat.expectTabVisible(channel);

  await bob.chat.sendMessage(`/join ${channel}`);
  await bob.chat.expectTabVisible(channel);

  await alice.chat.expectNickInList(bob.nick);
  await bob.chat.expectNickInList(alice.nick);

  return { alice, bob };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe('Whois and bio commands', () => {
  test('/bio appears in another user whois and /bio clear removes it (J10)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('bio');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const bio = `bio-${Date.now()}`;

    try {
      await bob.chat.sendMessage(`/bio ${bio}`);
      await bob.chat.expectMessageVisible(`Bio set: ${bio}`);

      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await alice.chat.expectWhoisCard(bob.nick);
      await alice.chat.expectLookupCardField('Bio', bio);
      await alice.chat.closeLookupResult();

      await bob.chat.sendMessage('/bio clear');
      await bob.chat.expectMessageVisible('Bio cleared.');

      await alice.chat.sendMessage(`/whois ${bob.nick}`);
      await alice.chat.expectWhoisCard(bob.nick);
      await alice.chat.expectLookupCardMissingField('Bio');
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('/whois shows online metadata, shared channels, registered state, away, and bio (J11)', async ({
    browser,
  }) => {
    const channel = uniqueChannel('meta');
    const { alice, bob } = await setupTwoUsersInChannel(browser, channel);
    const bio = `whois-bio-${Date.now()}`;
    const away = `whois-away-${Date.now()}`;

    try {
      await bob.chat.sendMessage(`/bio ${bio}`);
      await bob.chat.expectMessageVisible(`Bio set: ${bio}`);
      await bob.chat.sendMessage(`/away ${away}`);
      await bob.chat.expectMessageVisible(`You are now away: ${away}`);

      await alice.chat.sendMessage(`/whois ${bob.nick}`);

      await alice.chat.expectWhoisCard(bob.nick);
      await expect(alice.chat.lookupResultCard).toContainText('Online for');
      await expect(alice.chat.lookupResultCard).toContainText('Idle for');
      await alice.chat.expectLookupCardField('Channels', channel);
      await alice.chat.expectLookupCardField('Shared channels', channel);
      await alice.chat.expectLookupCardField('Registered', 'Yes');
      await alice.chat.expectLookupCardField('Away', away);
      await alice.chat.expectLookupCardField('Bio', bio);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test('/whois missingNick shows a not-online message (J12)', async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, 'wism');
    const missingNick = uniqueNickname('ghost');

    try {
      await alice.chat.sendMessage(`/whois ${missingNick}`);
      await alice.chat.expectMessageVisible(`* ${missingNick} is not online.`);
    } finally {
      await closeUsers([alice]);
    }
  });
});
