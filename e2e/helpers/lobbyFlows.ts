import { expect } from '@playwright/test';
import { P2PTestUser } from './p2pFlows';
import { LobbyPage, openLobbyByToken } from '../pages/LobbyPage';

/**
 * Drives the `/p2p` command end-to-end: the initiator invites the receiver,
 * both click the "Join lobby" card, and the two P2P-lobby pages open and
 * establish a connection.
 */
export async function openLobbiesFromCommand(
  initiator: P2PTestUser,
  receiver: P2PTestUser,
): Promise<{ initiatorLobby: LobbyPage; receiverLobby: LobbyPage }> {
  await initiator.chat.sendMessage(`/p2p ${receiver.nick}`);
  await initiator.chat.expectTabVisible(receiver.nick);
  await initiator.chat.expectTabSelected(receiver.nick);
  await initiator.chat.expectMessageVisible(
    `Lobby invite sent to ${receiver.nick}. Waiting for response...`,
  );

  return openLobbiesFromInviteCards(initiator, receiver);
}

/**
 * Drives the `P2P Lobby` nicklist context-menu entry point: the initiator
 * right-clicks the receiver in the nicklist (both must already share a channel)
 * and the same invite/join flow as the `/p2p` command unfolds.
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
  // The chat no longer links out to /lobby — the card carries the session
  // token as metadata, which these standalone-page tests use until F6.
  const initiatorCard = initiator.chat.p2pInviteCard();
  await expect(initiatorCard).toHaveAttribute(
    'data-session-token',
    /^[A-Za-z0-9_-]+$/,
  );
  const token = (await initiatorCard.getAttribute('data-session-token')) ?? '';

  await receiver.chat.expectTabVisible(initiator.nick);
  await receiver.chat.switchToTab(initiator.nick);
  await expect(receiver.chat.p2pInviteCard()).toHaveAttribute(
    'data-session-token',
    token,
  );

  const initiatorLobby = await openLobbyByToken(initiator.page, token);
  const receiverLobby = await openLobbyByToken(receiver.page, token);

  await initiatorLobby.waitUntilLiveViewConnected();
  await receiverLobby.waitUntilLiveViewConnected();

  return { initiatorLobby, receiverLobby };
}
