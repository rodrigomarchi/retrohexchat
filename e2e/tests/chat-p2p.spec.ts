import { test, expect, Page } from '@playwright/test';
import { newP2PUser, closeP2PUsers } from '../helpers/p2pFlows';

/**
 * In-chat P2P sessions (docs/plans/p2p-chat-integracao.md): the invite card
 * in the PM, accept/decline in place, the status-bar session area, and the
 * real WebRTC link established WITHOUT ever leaving /chat.
 */

function statusBarP2P(page: Page) {
  return page.getByTestId('status-bar-p2p');
}

function statusBarStop(page: Page) {
  return page.getByTestId('status-bar-p2p-stop');
}

test.describe('In-chat P2P session', () => {
  test('accepting the PM card connects both peers inside the chat', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'cpa', { media: true });
    const bob = await newP2PUser(browser, 'cpb', { media: true });

    try {
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await expect(statusBarP2P(alice.page)).toContainText('waiting for');

      // Bob accepts right on the PM card — no page navigation.
      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await bob.page.getByTestId('session-card-accept').click();

      // The WebRTC link comes up in place: the status bar flips to the
      // connected "P2P: <peer>" form on both sides.
      await expect(statusBarP2P(alice.page)).toContainText(`P2P: ${bob.nick}`, {
        timeout: 20_000,
      });
      await expect(statusBarP2P(bob.page)).toContainText(`P2P: ${alice.nick}`, {
        timeout: 20_000,
      });

      // The session presents itself: all four windows burst open on BOTH
      // sides, on top of the chat.
      for (const page of [alice.page, bob.page]) {
        for (const id of [
          'p2p-call-window',
          'p2p-files-window',
          'p2p-games-window',
          'p2p-stats-window',
        ]) {
          await expect(page.getByTestId(id)).toBeVisible();
        }
      }

      // Both PM tabs carry the session glyph, and the persisted P2P line
      // landed in the conversation.
      await expect(
        alice.page.getByTestId('tab-p2p-glyph').first(),
      ).toBeVisible();
      await alice.chat.expectMessageVisible('P2P session connected');

      // Alice ends the session from the status bar (with the confirm).
      await statusBarStop(alice.page).click();
      await alice.page.getByTestId('p2p-confirm-dialog-confirm').click();
      await expect(statusBarP2P(alice.page)).toBeHidden();
      await expect(statusBarP2P(bob.page)).toBeHidden({ timeout: 10_000 });
      await alice.chat.expectMessageVisible('ended the P2P session');

      // Ending closes every session window, on both sides.
      for (const page of [alice.page, bob.page]) {
        for (const id of [
          'p2p-call-window',
          'p2p-files-window',
          'p2p-games-window',
          'p2p-stats-window',
        ]) {
          await expect(page.getByTestId(id)).toBeHidden();
        }
      }
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('declining the invite tells the inviter and clears the pending state', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'cpc');
    const bob = await newP2PUser(browser, 'cpd');

    try {
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await expect(statusBarP2P(alice.page)).toBeVisible();

      await bob.chat.expectTabVisible(alice.nick);
      await bob.chat.switchToTab(alice.nick);
      await bob.page.getByTestId('session-card-decline').click();

      await alice.chat.expectMessageVisible('declined the P2P invite');
      await expect(statusBarP2P(alice.page)).toBeHidden();
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });

  test('the inviter cancels a pending invite from the status bar', async ({
    browser,
  }) => {
    const alice = await newP2PUser(browser, 'cpe');
    const bob = await newP2PUser(browser, 'cpf');

    try {
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await expect(statusBarP2P(alice.page)).toContainText('waiting for');

      await statusBarStop(alice.page).click();
      await expect(statusBarP2P(alice.page)).toBeHidden();
      await alice.chat.expectMessageVisible('cancelled the P2P invite');
    } finally {
      await closeP2PUsers([alice, bob]);
    }
  });
});
