import { test, expect } from '@playwright/test';
import {
  ADMIN_NICK,
  ADMIN_PW,
  closeUsers,
  knownSignedInUser,
  newSignedInUser,
  uniqueChannel,
} from '../helpers/chatUsers';

test.describe.serial('UI feature shell journeys', () => {
  test('Account dialog covers registration, profile, presence, and user modes (Feature 01)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'uifa', 'pass12345');
    const bio = `account-bio-${Date.now()}`;

    try {
      await expect(user.chat.statusBarAccountWidget).toContainText(user.nick);
      await expect(user.chat.statusBarAccountWidget).toContainText('Identified');

      await user.chat.openAccountRegisterFromMenu();
      await expect(user.chat.accountDialog).toContainText(
        'You are identified with NickServ.',
      );

      await user.chat.accountDropPasswordInput.fill(user.password);
      await user.chat.accountDialog
        .getByRole('button', { name: 'Drop Registration', exact: true })
        .click();
      await expect(user.chat.accountDialog.getByTestId('account-register-only'))
        .toBeVisible();

      await user.chat.accountPasswordInput.fill('newpass123');
      await user.chat.accountConfirmInput.fill('newpass123');
      await expect(
        user.chat.accountDialog.getByRole('button', {
          name: 'Register',
          exact: true,
        }),
      ).toBeEnabled();
      await user.chat.accountDialog
        .getByRole('button', { name: 'Register', exact: true })
        .click();
      await expect(user.chat.accountDialog.getByTestId('account-identified-state'))
        .toBeVisible();

      await user.chat.accountDialog.getByRole('button', { name: 'Profile' }).click();
      await user.chat.accountBioInput.fill(bio);
      await user.chat.accountDialog.getByRole('button', { name: 'Save Bio' }).click();

      await user.chat.accountDialog.getByRole('button', { name: 'Presence' }).click();
      await user.chat.accountDialog
        .locator('input[type="checkbox"][name="away"]')
        .check();
      await user.chat.accountAwayMessageInput.fill('reviewing UI features');
      await user.chat.accountDialog.getByRole('button', { name: 'Set Away' }).click();
      await expect(user.chat.statusBarAccountWidget).toContainText('Away');
      await expect(user.chat.statusBarAwayToggle).toHaveAttribute(
        'aria-label',
        'Back',
      );

      await user.chat.accountDialog.getByRole('button', { name: 'User Modes' }).click();
      await user.chat.accountDialog
        .locator('input[type="checkbox"][name="wallops"]')
        .check();
      await user.chat.accountDialog.getByRole('button', { name: 'Apply' }).click();
      await user.chat.accountDialog.getByText('Close', { exact: true }).click();
      await expect(user.chat.accountDialog).toBeHidden();
      await user.chat.switchToStatusTab();
      await user.chat.expectStatusMessageVisible('User mode +w enabled.');

      await user.chat.sendMessage(`/whois ${user.nick}`);
      await expect(user.chat.lookupResultCard).toContainText(bio);
    } finally {
      await closeUsers([user]);
    }
  });

  test('Notify List and Bot Management are reachable from their new entry points (Features 02 and 03)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'uifn');
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await user.chat.openNotifyListFromViewMenu();
      await expect(user.chat.notifyListDialog).toContainText('Notify List');
      await user.chat.closeNotifyList();

      await user.chat.toolsMenuTrigger.click();
      await expect(user.chat.botManagementMenuItem).toHaveCount(0);

      await admin.chat.openBotManagementFromToolsMenu();
      await expect(admin.chat.botManagementDialog).toContainText('Bot Management');
    } finally {
      await closeUsers([user, admin]);
    }
  });

  test('Edit menu clears the active window, finds text, and copies selected text (Feature 04)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'uife');
    const marker = `edit-copy-${Date.now()}`;

    try {
      await user.ctx.grantPermissions(['clipboard-read', 'clipboard-write']);
      await user.chat.sendMessage(marker);
      await user.chat.expectMessageVisible(marker);

      const triggers = await user.chat.menuBar
        .locator('button[data-menubar-trigger]')
        .allTextContents();
      expect(triggers.map((label) => label.trim())).toEqual([
        'File',
        'Edit',
        'View',
        'Tools',
        'Help',
      ]);

      await user.chat.messageRowByText(marker).evaluate((el) => {
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(el);
        selection?.removeAllRanges();
        selection?.addRange(range);
        document.dispatchEvent(new Event('selectionchange', { bubbles: true }));
      });

      await user.chat.editMenuTrigger.click();
      await expect(user.chat.copySelectionMenuItem).toBeVisible();
      await expect(user.chat.copySelectionMenuItem).toHaveAttribute(
        'data-copy-disabled',
        'false',
      );
      await user.chat.copySelectionMenuItem.click();
      await expect
        .poll(() => user.page.evaluate(() => navigator.clipboard.readText()))
        .toContain(marker);

      await user.chat.openSearchFromEditMenu();
      await user.chat.searchBarInput.fill(marker);
      await expect(user.chat.searchBarCount).toContainText('1');
      await user.chat.searchBar.getByRole('button', { name: 'Close' }).click();

      await user.chat.editMenuTrigger.click();
      await expect(user.chat.clearWindowMenuItem).toBeVisible();
      await user.chat.clearWindowMenuItem.click();
      await user.chat.expectMessageHidden(marker);
    } finally {
      await closeUsers([user]);
    }
  });

  test('Action toggle and Send Notice composer send through the real input (Feature 07)', async ({
    browser,
  }) => {
    const sender = await newSignedInUser(browser, 'uifs');
    const target = await newSignedInUser(browser, 'uift');
    const channel = uniqueChannel('uifm');
    const action = `waves-${Date.now()}`;
    const notice = `notice-${Date.now()}`;

    try {
      await sender.chat.sendMessage(`/join ${channel}`);
      await sender.chat.expectTabVisible(channel);
      await target.chat.sendMessage(`/join ${channel}`);
      await target.chat.expectTabVisible(channel);
      await sender.chat.switchToTab(channel);
      await target.chat.switchToTab(channel);

      await sender.page.getByTestId('chat-action-toggle').click();
      await expect(sender.chat.chatInput).toHaveAttribute(
        'placeholder',
        'What are you doing? (/me mode)',
      );
      await sender.chat.sendMessage(action);
      await sender.chat.expectMessageVisible(`* ${sender.nick} ${action}`);

      await sender.chat.openNicklistContextMenu(target.nick);
      await sender.page.getByTestId('context-menu-item-context_notice').click();
      await expect(sender.page.getByTestId('chat-notice-composer')).toContainText(
        `Notice to ${target.nick}:`,
      );
      await sender.chat.chatInput.fill(notice);
      await expect(sender.chat.chatSendButton).toBeEnabled();
      await sender.chat.chatSendButton.click();
      await expect(sender.page.getByTestId('chat-notice-composer')).toBeHidden();
      await expect(sender.chat.chatInput).toHaveValue('');

      await target.chat.expectMessageVisible(notice);
      await expect(sender.chat.tab(target.nick)).toHaveCount(0);
    } finally {
      await closeUsers([sender, target]);
    }
  });

  test('Timers dialog opens from Tools and bare /timer, validates, saves, and stops timers (Feature 08)', async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, 'uiftm');
    const timerName = `tm${Date.now().toString(36)}`;

    try {
      await user.chat.openTimersFromToolsMenu();
      await expect(user.chat.timersDialog).toContainText(
        'No active timers. Click Add to schedule one.',
      );

      await user.chat.timersDialog.getByTestId('timers-dialog-add').click();
      await user.chat.timersEditForm.getByTestId('timer-name-input').fill(timerName);
      await user.chat.timersEditForm.getByTestId('timer-repeat-checkbox').check();
      await user.chat.timersEditForm.getByTestId('timer-seconds-input').fill('5');
      await user.chat.timersEditForm
        .getByTestId('timer-command-input')
        .fill('/me too fast');
      await user.chat.timersEditForm.getByRole('button', { name: 'Save' }).click();
      await expect(user.chat.timersEditForm).toContainText(
        'min 10s for repeating timers',
      );

      await user.chat.timersEditForm.getByTestId('timer-repeat-checkbox').uncheck();
      await user.chat.timersEditForm.getByTestId('timer-seconds-input').fill('60');
      await user.chat.timersEditForm
        .getByTestId('timer-command-input')
        .fill('/me delayed action');
      await user.chat.timersEditForm.getByRole('button', { name: 'Save' }).click();
      await expect(user.page.getByTestId(`timer-row-${timerName}`)).toBeVisible();

      await user.page.getByTestId(`timer-row-${timerName}`).click();
      await user.chat.timersDialog.getByTestId('timers-dialog-stop').click();
      await expect(user.page.getByTestId(`timer-row-${timerName}`)).toHaveCount(0);

      await user.chat.timersDialog.getByText('Close', { exact: true }).click();
      await expect(user.chat.timersDialog).toBeHidden();
      await user.chat.sendMessage('/timer');
      await expect(user.chat.timersDialog).toBeVisible();
    } finally {
      await closeUsers([user]);
    }
  });

  test('User Lookup dialog and result cards cover whois, query, and whowas flows (Feature 10)', async ({
    browser,
  }) => {
    const actor = await newSignedInUser(browser, 'uifl');
    const target = await newSignedInUser(browser, 'uifw');

    try {
      await actor.chat.openUserLookupFromToolsMenu();
      await actor.page.getByTestId('user-lookup-nickname').fill(target.nick);
      await actor.page.getByTestId('user-lookup-whois').click();
      await expect(actor.chat.lookupResultDialog).toBeVisible();
      await expect(actor.chat.lookupResultCard).toContainText(`Nickname:`);
      await expect(actor.chat.lookupResultCard).toContainText(target.nick);

      await actor.page.getByTestId('lookup-result-query').click();
      await actor.chat.expectTabVisible(target.nick);

      await target.chat.disconnect();
      await expect(actor.chat.lookupResultDialog).toBeHidden();
      await actor.chat.openUserLookupFromToolsMenu();
      await actor.page.getByTestId('user-lookup-nickname').fill(target.nick);
      await actor.page.getByTestId('user-lookup-whowas').click();
      await expect(actor.chat.lookupResultDialog).toBeVisible();
      await expect(actor.chat.lookupResultCard).toContainText('Last seen:');
      await expect(actor.chat.lookupResultCard).toContainText(target.nick);
    } finally {
      await closeUsers([actor, target]);
    }
  });
});
