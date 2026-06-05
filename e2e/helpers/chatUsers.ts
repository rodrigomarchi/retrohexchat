import { Browser, BrowserContext, Page } from '@playwright/test';
import { ChatPage } from '../pages/ChatPage';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';

export type TestUser = {
  chat: ChatPage;
  connect: ConnectPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
  password: string;
};

export const ADMIN_NICK = 'TestAdmin';
export const ADMIN_PW = 'adminpass1';

export async function newSignedInUser(
  browser: Browser,
  prefix = 'uif',
  password = 'pass12345',
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password };
}

export async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password };
}

export async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close().catch(() => {})));
}

export function uniqueChannel(prefix = 'uif'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}
