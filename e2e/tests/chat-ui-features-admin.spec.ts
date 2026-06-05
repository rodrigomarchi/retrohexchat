import { test, expect } from '@playwright/test';
import {
  ADMIN_NICK,
  ADMIN_PW,
  closeUsers,
  knownSignedInUser,
  newSignedInUser,
  uniqueChannel,
} from '../helpers/chatUsers';

test.describe.serial('UI feature admin journeys', () => {
  test('Admin Console structured tabs and MOTD menu exercise safe admin UI paths (Feature 12)', async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const observer = await newSignedInUser(browser, 'uifao');
    const target = await newSignedInUser(browser, 'uifat');
    const channel = uniqueChannel('uifad');
    const newDescription = `admin-console-description-${Date.now()}`;
    const motd = `admin-console-motd-${Date.now()}`;
    const announcement = `admin-console-announcement-${Date.now()}`;
    const tabPanel = (tab: string) =>
      admin.page.getByTestId(`admin-console-tab-${tab.replaceAll('_', '-')}`);
    const inlineResult = (tab: string) =>
      tabPanel(tab).getByTestId('admin-console-inline-result');

    try {
      await admin.chat.openAdminConsoleFromMenu();

      const tabLabels = await admin.chat.adminConsoleDialog
        .locator('[data-testid^="admin-console-tab-label-"]')
        .allTextContents();
      expect(tabLabels.map((label) => label.trim())).toEqual([
        'Server Settings',
        'Users',
        'Channels',
        'MOTD',
        'Broadcast',
        'Audit Log',
        'TURN',
        'Danger Zone',
        'Console',
      ]);

      await admin.chat.switchAdminConsoleToTab('server_settings');
      const descriptionInput = admin.page.locator(
        '#admin-console-server-description',
      );
      const originalDescription = await descriptionInput.inputValue();
      await descriptionInput.fill(newDescription);
      await admin.page
        .locator('#admin-console-server-settings-form')
        .getByRole('button', { name: 'Save settings' })
        .click();
      await expect(inlineResult('server_settings')).toContainText(newDescription);

      await admin.page
        .locator('#admin-console-server-settings-form')
        .getByRole('button', { name: 'Start solo arcade' })
        .click();
      await expect(inlineResult('server_settings')).toContainText('Done');
      await admin.chat.expectMessageVisible('Arcade session ready!');
      await expect(admin.chat.arcadeSessionLink()).toHaveAttribute(
        'href',
        /^\/solo\/[A-Za-z0-9_-]+$/,
      );

      await admin.chat.switchAdminConsoleToTab('users');
      await admin.page.locator('#admin-console-user-info-nick').fill(target.nick);
      await admin.page
        .locator('#admin-console-user-info-form')
        .getByRole('button', { name: 'Info' })
        .click();
      await expect(inlineResult('users')).toContainText(`*** User: ${target.nick}`);

      await admin.page
        .locator('#admin-console-user-mute-form input[name="nick"]')
        .fill(target.nick);
      await admin.page
        .locator('#admin-console-user-mute-form input[name="duration"]')
        .fill('30s');
      await admin.page
        .locator('#admin-console-user-mute-form')
        .getByRole('button', { name: 'Confirm mute' })
        .click();
      await expect(inlineResult('users')).toContainText(
        `${target.nick} has been muted`,
      );

      await admin.page
        .locator('#admin-console-user-unmute-form input[name="nick"]')
        .fill(target.nick);
      await admin.page
        .locator('#admin-console-user-unmute-form')
        .getByRole('button', { name: 'Confirm unmute' })
        .click();
      await expect(inlineResult('users')).toContainText(
        `${target.nick} has been unmuted.`,
      );

      await admin.chat.switchAdminConsoleToTab('channels');
      await admin.page.locator('#admin-console-channel-create-name').fill(channel);
      await admin.page
        .locator('#admin-console-channel-create-form')
        .getByRole('button', { name: 'Create' })
        .click();
      await expect(inlineResult('channels'))
        .toContainText(`Channel ${channel} created and registered.`);

      await admin.page.locator('#admin-console-channel-info-name').fill(channel);
      await admin.page
        .locator('#admin-console-channel-info-form')
        .getByRole('button', { name: 'Info' })
        .click();
      await expect(inlineResult('channels')).toContainText(
        `*** Channel: ${channel}`,
      );

      await admin.page
        .locator('#admin-console-channel-delete-form input[name="channel"]')
        .fill(channel);
      await admin.page
        .locator('#admin-console-channel-delete-form input[name="confirm"]')
        .fill(channel);
      await admin.page
        .locator('#admin-console-channel-delete-form')
        .getByRole('button', { name: 'Confirm delete' })
        .click();
      await expect(inlineResult('channels'))
        .toContainText(`Channel ${channel} has been deleted.`);

      await admin.chat.switchAdminConsoleToTab('motd');
      await admin.page.locator('#admin-console-motd-input').fill(motd);
      await admin.page
        .locator('#admin-console-motd-form')
        .getByRole('button', { name: 'Set MOTD' })
        .click();
      await expect(admin.page.getByTestId('admin-console-motd-result'))
        .toContainText('MOTD has been updated.');
      await expect(admin.page.locator('#admin-console-motd-current'))
        .toContainText(motd);

      await observer.chat.openMessageOfTheDayFromHelpMenu();
      await observer.chat.switchToStatusTab();
      await observer.chat.expectStatusMessageVisible(motd);
      await observer.chat.switchToTab('#lobby');

      await admin.chat.switchAdminConsoleToTab('broadcast');
      await admin.page
        .locator('#admin-console-broadcast-form input[value="announce"]')
        .check();
      await admin.page
        .locator('#admin-console-broadcast-message')
        .fill(announcement);
      await admin.page
        .locator('#admin-console-broadcast-form')
        .getByRole('button', { name: 'Send broadcast' })
        .click();
      await expect(inlineResult('broadcast'))
        .toContainText('Announcement sent to all users.');
      await observer.chat.expectMessageVisible(announcement);

      await admin.chat.switchAdminConsoleToTab('turn');
      await expect(admin.page.locator('#admin-console-turn-stats'))
        .toContainText('TURN');
      await admin.page
        .getByTestId('admin-console-tab-turn')
        .getByRole('button', { name: 'Refresh' })
        .click();
      await expect(admin.page.locator('#admin-console-turn-allocations'))
        .toContainText(/allocation/i);

      await admin.chat.switchAdminConsoleToTab('audit_log');
      await admin.page.locator('#admin-console-audit-log-last').fill('5');
      await admin.page.locator('#admin-console-audit-log-user').fill(ADMIN_NICK);
      await admin.page
        .locator('#admin-console-audit-log-form')
        .getByRole('button', { name: 'Refresh' })
        .click();
      await expect(admin.page.locator('#admin-console-audit-log-output'))
        .toContainText(ADMIN_NICK);

      await admin.chat.switchAdminConsoleToTab('danger_zone');
      await expect(admin.page.locator('#admin-console-danger-preview'))
        .toContainText(/nuke/i);
      await admin.page.locator('#admin-console-danger-confirm').fill('wrong');
      await expect(
        admin.page
          .locator('#admin-console-danger-zone-form')
          .getByRole('button', { name: 'NUKE EVERYTHING' }),
      ).toBeDisabled();

      await admin.chat.switchAdminConsoleToTab('console');
      await admin.chat.adminConsoleInput.fill('admin server get registration');
      await admin.chat.adminConsoleDialog.getByRole('button', { name: 'Run' }).click();
      await expect(admin.chat.adminConsoleOutput).toContainText('registration');

      await admin.chat.switchAdminConsoleToTab('motd');
      await admin.page
        .locator('#admin-console-motd-form')
        .getByRole('button', { name: 'Clear MOTD' })
        .click();
      await expect(admin.page.getByTestId('admin-console-motd-result'))
        .toContainText('MOTD has been cleared.');

      await admin.chat.switchAdminConsoleToTab('server_settings');
      await admin.page
        .locator('#admin-console-server-description')
        .fill(originalDescription);
      await admin.page
        .locator('#admin-console-server-settings-form')
        .getByRole('button', { name: 'Save settings' })
        .click();
    } finally {
      await closeUsers([admin, observer, target]);
    }
  });
});
