import { Page, test } from '@playwright/test';
import { ConnectPage, uniqueNickname } from '../pages/ConnectPage';
import { ChatPage } from '../pages/ChatPage';

function uniqueChannel(prefix = 'ccsync'): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = 'ccsync') {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword('pass12345');
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe('Channel Central sync', () => {
  test('topic and mode edits stay synced with slash commands after reopen (U16)', async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page);
    const channel = uniqueChannel('ccsync');
    const dialogTopic = `dialog topic ${Date.now()}`;
    const slashTopic = `slash topic ${Date.now()}`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.openChannelCentralFromMenu();
    await chat.setChannelCentralTopic(dialogTopic);
    await chat.closeChannelCentral();
    await chat.expectMessageVisible(`${nick} changed the topic to: ${dialogTopic}`);

    await chat.sendMessage('/topic');
    await chat.expectMessageVisible(`Topic for ${channel}: ${dialogTopic}`);

    await chat.openChannelCentralFromMenu();
    await chat.expectChannelCentralTopic(dialogTopic);
    await chat.closeChannelCentral();

    await chat.sendMessage(`/topic ${slashTopic}`);
    await chat.expectMessageVisible(`${nick} changed the topic to: ${slashTopic}`);

    await chat.openChannelCentralFromMenu();
    await chat.expectChannelCentralTopic(slashTopic);
    await chat.setChannelCentralModerated(true);
    await chat.expectMessageVisible(`${nick} sets mode +m`);
    await chat.setChannelCentralInviteOnly(true);
    await chat.expectMessageVisible(`${nick} sets mode +i`);
    await chat.closeChannelCentral();

    await chat.openChannelCentralFromMenu();
    await chat.expectChannelCentralMode('Moderated (+m)', true);
    await chat.expectChannelCentralMode('Invite Only (+i)', true);
    await chat.closeChannelCentral();

    await chat.sendMessage('/mode -m');
    await chat.expectMessageVisible(`${nick} sets mode -m`);

    await chat.openChannelCentralFromMenu();
    await chat.expectChannelCentralMode('Moderated (+m)', false);
    await chat.expectChannelCentralMode('Invite Only (+i)', true);
    await chat.closeChannelCentral();

    await chat.sendMessage('/mode -i');
    await chat.expectMessageVisible(`${nick} sets mode -i`);

    await chat.openChannelCentralFromMenu();
    await chat.expectChannelCentralMode('Moderated (+m)', false);
    await chat.expectChannelCentralMode('Invite Only (+i)', false);
    await chat.closeChannelCentral();
  });
});
