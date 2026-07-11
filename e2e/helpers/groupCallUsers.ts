import { Browser } from '@playwright/test';
import { ChatPage } from '../pages/ChatPage';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { closeUsers, TestUser } from './chatUsers';
import { installSyntheticMedia } from './syntheticMedia';

export type GroupCallUser = TestUser;

export async function newGroupCallUser(
  browser: Browser,
  prefix = 'gcu',
): Promise<GroupCallUser> {
  const ctx = await browser.newContext({
    permissions: ['microphone', 'camera'],
  });

  await installSyntheticMedia(ctx);

  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  const password = 'pass12345';

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password };
}

export async function closeGroupCallUsers(users: GroupCallUser[]) {
  await closeUsers(users);
}
