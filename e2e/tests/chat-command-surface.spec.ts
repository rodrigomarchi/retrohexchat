import { test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

async function signedInUser(page: import('@playwright/test').Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname());
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();
  return chat;
}

test.describe('Command surface validation', () => {
  test('unknown slash command shows the help hint in the active message list (G1)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    const command = `/notacommand${Date.now()}`;
    await chat.sendMessage(command);

    await chat.expectMessageVisible(
      `Unknown command: ${command}. Type /help for a list of commands.`,
    );
  });

  test('missing required arguments show usage for representative user commands (G2)', async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.sendMessage('/msg');
    await chat.expectMessageVisible('Usage: /msg <nickname> <message>');

    await chat.sendMessage('/join');
    await chat.expectMessageVisible('Usage: /join #channel [password]');

    await chat.sendMessage('/mode');
    await chat.expectMessageVisible('Usage: /mode <+/-flags> [params]');

    await chat.sendMessage('/ns');
    await chat.expectMessageVisible(
      'Usage: /ns <register|identify|ghost|info|drop|help> [args]',
    );
  });

  test('admin command usage is visible to an authenticated admin (G2)', async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.signIn('TestAdmin', 'adminpass1');
    await chat.waitUntilConnected();

    await chat.sendMessage('/admin');
    await chat.expectMessageVisible(
      'Usage: /admin <server|user|channel|ns|cs|debug|log|turn|nuke> <subcommand> [args]',
    );
  });
});
