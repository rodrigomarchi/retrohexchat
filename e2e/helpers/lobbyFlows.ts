import { expect } from '@playwright/test';
import { P2PTestUser } from './p2pFlows';
import { LobbyPage, openLobbyFromInvite } from '../pages/LobbyPage';

/**
 * Drives the `/lobby` command end-to-end: the initiator invites the receiver,
 * both click the "Join lobby" card, and the two universal-lobby pages open and
 * establish a connection.
 */
export async function openLobbiesFromCommand(
  initiator: P2PTestUser,
  receiver: P2PTestUser,
): Promise<{ initiatorLobby: LobbyPage; receiverLobby: LobbyPage }> {
  await initiator.chat.sendMessage(`/lobby ${receiver.nick}`);
  await initiator.chat.expectTabVisible(receiver.nick);
  await initiator.chat.expectTabSelected(receiver.nick);
  await initiator.chat.expectMessageVisible(
    `Lobby invite sent to ${receiver.nick}. Waiting for response...`,
  );

  return openLobbiesFromInviteCards(initiator, receiver);
}

/**
 * Drives the `Universal Lobby` nicklist context-menu entry point: the initiator
 * right-clicks the receiver in the nicklist (both must already share a channel)
 * and the same invite/join flow as the `/lobby` command unfolds.
 */
export async function openLobbiesFromContextMenu(
  initiator: P2PTestUser,
  receiver: P2PTestUser,
): Promise<{ initiatorLobby: LobbyPage; receiverLobby: LobbyPage }> {
  await initiator.chat.openNicklistContextMenu(receiver.nick);
  await initiator.page
    .getByTestId('context-menu-item-context_lobby')
    .click();

  await initiator.chat.expectMessageVisible(
    `Lobby invite sent to ${receiver.nick}. Waiting for response...`,
  );

  return openLobbiesFromInviteCards(initiator, receiver);
}

async function openLobbiesFromInviteCards(
  initiator: P2PTestUser,
  receiver: P2PTestUser,
): Promise<{ initiatorLobby: LobbyPage; receiverLobby: LobbyPage }> {
  const initiatorLink = initiator.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(initiatorLink).toHaveAttribute(
    'href',
    /^\/lobby\/[A-Za-z0-9_-]+$/,
  );
  const inviteHref = await initiatorLink.getAttribute('href');

  await receiver.chat.expectTabVisible(initiator.nick);
  await receiver.chat.switchToTab(initiator.nick);

  const receiverLink = receiver.chat
    .p2pInviteCard()
    .getByRole('link', { name: 'Join lobby' });
  await expect(receiverLink).toHaveAttribute('href', inviteHref ?? '');

  const initiatorLobby = await openLobbyFromInvite(initiator.page, initiatorLink);
  const receiverLobby = await openLobbyFromInvite(receiver.page, receiverLink);

  await initiatorLobby.waitUntilLiveViewConnected();
  await receiverLobby.waitUntilLiveViewConnected();

  return { initiatorLobby, receiverLobby };
}
