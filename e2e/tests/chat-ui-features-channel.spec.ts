import { test, expect } from '@playwright/test';
import {
  closeUsers,
  newSignedInUser,
  uniqueChannel,
} from '../helpers/chatUsers';

test.describe.serial('UI feature channel journeys', () => {
  test('moderation context menu grants/removes roles and mutes/unmutes channel sends (Feature 05)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'uifmo');
    const target = await newSignedInUser(browser, 'uifmt');
    const channel = uniqueChannel('uifmod');
    const blocked = `blocked-${Date.now()}`;
    const restored = `restored-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await target.chat.sendMessage(`/join ${channel}`);
      await owner.chat.switchToTab(channel);

      await owner.chat.openNicklistContextMenu(target.nick);
      await owner.page.getByTestId('context-menu-item-context_voice').click();
      await owner.chat.expectNickRole(target.nick, 'voiced');

      await owner.chat.openNicklistContextMenu(target.nick);
      await owner.page.getByTestId('context-menu-item-context_devoice').click();
      await owner.chat.expectNickRole(target.nick, 'regular');

      await owner.chat.openNicklistContextMenu(target.nick);
      await owner.page.getByTestId('context-menu-item-context_op').click();
      await owner.chat.expectNickRole(target.nick, 'operator');

      await owner.chat.openNicklistContextMenu(target.nick);
      await owner.page.getByTestId('context-menu-item-context_deop').click();
      await owner.chat.expectNickRole(target.nick, 'regular');

      await owner.chat.openNicklistContextMenu(target.nick);
      await owner.page.getByTestId('context-menu-item-context_mute').click();
      await expect(owner.chat.muteDurationDialog).toBeVisible();
      await owner.chat.muteDurationDialog
        .getByTestId('mute-duration-input')
        .fill('30s');
      await owner.chat.muteDurationDialog.getByRole('button', { name: 'OK' }).click();
      await expect(owner.chat.muteDurationDialog).toBeHidden();

      await target.chat.switchToTab(channel);
      await target.chat.sendMessage(blocked);
      await target.chat.expectMessageVisible('You are muted in this channel');
      await owner.chat.expectMessageHidden(blocked);

      await owner.chat.openNicklistContextMenu(target.nick);
      await owner.page.getByTestId('context-menu-item-context_unmute').click();
      await target.chat.sendMessage(restored);
      await owner.chat.expectMessageVisible(restored);
    } finally {
      await closeUsers([owner, target]);
    }
  });

  test('invite picker and Channel List knock request drive invite-only membership (Feature 06)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'uifio');
    const target = await newSignedInUser(browser, 'uifit');
    const guest = await newSignedInUser(browser, 'uifik');
    const channel = uniqueChannel('uifinv');
    const knockMessage = `please-let-me-in-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.sendMessage('/mode +i');
      await owner.chat.expectMessageVisible(`${owner.nick} sets mode +i`);

      await owner.chat.switchToTab('#lobby');
      await owner.chat.openNicklistContextMenu(target.nick);
      await owner.page
        .getByTestId('context-menu-item-context_invite_to_channel')
        .click();
      await expect(owner.chat.inviteChannelPickerDialog).toBeVisible();
      await owner.chat.inviteChannelPickerDialog
        .getByTestId('invite-channel-picker-select')
        .selectOption(channel);
      await owner.chat.inviteChannelPickerDialog
        .getByTestId('invite-channel-submit')
        .click();
      await expect(owner.chat.inviteChannelPickerDialog).toBeHidden();

      await target.chat.acceptInvite(channel);
      await target.chat.expectTabVisible(channel);

      await guest.chat.viewMenuTrigger.click();
      await guest.chat.channelListMenuItem.click();
      await expect(guest.chat.channelListDialog).toBeVisible();
      await guest.chat.channelListSearch.fill(channel);
      await expect(guest.chat.channelListRow(channel)).toBeVisible();
      await guest.chat.channelListRow(channel).click();
      await expect(
        guest.page.getByTestId(`channel-list-invite-only-${channel}`),
      ).toBeVisible();
      await guest.page.getByTestId('channel-list-knock').click();
      await expect(guest.chat.knockRequestDialog).toBeVisible();
      await guest.chat.knockRequestDialog
        .getByTestId('knock-request-message')
        .fill(knockMessage);
      await guest.chat.knockRequestDialog
        .getByTestId('knock-request-submit')
        .click();
      await expect(guest.chat.knockRequestDialog).toBeHidden();
      await guest.chat.expectMessageVisible(`Knock sent to ${channel}`);
    } finally {
      await closeUsers([owner, target, guest]);
    }
  });

  test('Channel Central saves welcome, throttle, and ownership transfer controls (Feature 09)', async ({
    browser,
  }) => {
    const owner = await newSignedInUser(browser, 'uifco');
    const target = await newSignedInUser(browser, 'uifct');
    const channel = uniqueChannel('uifcc');
    const welcome = `welcome-${Date.now()}`;

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await target.chat.sendMessage(`/join ${channel}`);
      await owner.chat.switchToTab(channel);

      await owner.chat.openChannelCentralFromMenu();
      await owner.chat.channelCentralPanel('general')
        .getByTestId('cc-welcome-message-input')
        .fill(welcome);
      await owner.chat.channelCentralPanel('general')
        .getByRole('button', { name: 'Save Welcome' })
        .click();
      await expect(owner.chat.channelCentralDialog).toContainText(
        'Welcome message saved.',
      );
      await expect(
        owner.chat.channelCentralPanel('general')
          .getByTestId('cc-welcome-message-input'),
      ).toHaveValue(welcome);

      await owner.chat.channelCentralPanel('general')
        .getByTestId('cc-throttle-seconds-input')
        .fill('45');
      await owner.chat.channelCentralPanel('general')
        .getByRole('button', { name: 'Apply Throttle' })
        .click();
      await expect(owner.chat.channelCentralDialog).toContainText(
        'Join throttle set to 45 seconds.',
      );

      await owner.chat.channelCentralPanel('general')
        .getByTestId('cc-transfer-open')
        .click();
      await expect(owner.page.getByTestId('cc-transfer-dialog')).toBeVisible();
      await owner.page.getByTestId('cc-transfer-nick-input').fill(target.nick);
      await owner.page
        .getByTestId('cc-transfer-dialog')
        .getByRole('button', { name: 'Transfer' })
        .click();
      await expect(owner.page.getByTestId('cc-transfer-dialog')).toHaveCount(0);
      await expect(owner.chat.channelCentralDialog).toContainText(
        `Channel ownership transferred to ${target.nick}.`,
      );
      await owner.chat.expectNickRole(target.nick, 'owner');
    } finally {
      await closeUsers([owner, target]);
    }
  });

  test('Channel Central Registration tab registers ChanServ access and edits AOP (Feature 11)', async ({
    browser,
  }) => {
    const founder = await newSignedInUser(browser, 'uifcf');
    const target = await newSignedInUser(browser, 'uifca');
    const channel = uniqueChannel('uifcs');

    try {
      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.switchToTab(channel);
      await founder.chat.openChannelCentralFromMenu();
      await founder.chat.switchChannelCentralToTab('registration');
      await expect(founder.chat.channelCentralDialog).toContainText('Not registered');

      await founder.page.getByTestId('cc-cs-register').click();
      await expect(founder.chat.channelCentralDialog).toContainText('Registered');
      await expect(founder.chat.channelCentralDialog).toContainText(founder.nick);

      await founder.page.getByTestId('cc-cs-access-tab-aop').click();
      await founder.page.getByTestId('cc-cs-access-nick').fill(target.nick);
      await founder.page.getByTestId('cc-cs-access-add').click();
      await expect(founder.page.getByTestId(`cc-cs-access-row-${target.nick}`))
        .toBeVisible();

      await founder.page.getByTestId(`cc-cs-access-row-${target.nick}`).click();
      await founder.page.getByTestId('cc-cs-access-remove').click();
      await expect(founder.page.getByTestId(`cc-cs-access-row-${target.nick}`))
        .toHaveCount(0);
    } finally {
      await closeUsers([founder, target]);
    }
  });
});
