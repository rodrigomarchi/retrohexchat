import { expect, Page } from "@playwright/test";
import { writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { TestUser } from "../helpers/chatUsers";
import { openConference } from "../helpers/groupCallUsers";
import {
  acceptP2PInvite,
  remoteVideoLive,
  sendP2PInvite,
  startP2PSession,
} from "../helpers/p2pFlows";

/**
 * Private sessions and channel conferences on film.
 *
 * Built on the suite's p2pFlows: `/p2p <nick>` writes a session card, each
 * side follows it into a tab of its own (following it is the consent), and
 * the inviter starts the session. Cameras are the director's test cards.
 */

export type Session = { inviter: Page; invitee: Page };

/**
 * Opens a private session from `inviter` to `invitee`, both sides in, video
 * live both ways. The invitee is driven off camera.
 */
export async function openSession(
  inviter: TestUser,
  invitee: TestUser,
  onInviterTab?: (tab: Page) => Promise<unknown>,
): Promise<Session> {
  const inviterTab = await sendP2PInvite(inviter, invitee.nick);
  await onInviterTab?.(inviterTab);
  await invitee.chat.switchToTab(inviter.nick);
  const inviteeTab = await acceptP2PInvite(invitee);
  await startP2PSession(inviterTab);
  for (const tab of [inviterTab, inviteeTab]) {
    await expect
      .poll(() => remoteVideoLive(tab), { timeout: 30_000 })
      .toBe(true);
  }
  return { inviter: inviterTab, invitee: inviteeTab };
}

/** Ends a session from one side and closes both tabs. */
export async function endSession(session: Session) {
  await session.inviter.getByTestId("p2p-console-end-session").click();
  await session.inviter.getByTestId("p2p-confirm-dialog-confirm").click();
  await session.inviter.close();
  await session.invitee.close();
}

/**
 * Sends a file large enough for its progress bar to be seen, and has the
 * other side take it.
 */
export async function sendFile(session: Session, file: string) {
  const name = path.basename(file);
  await consoleSection(session.inviter, "files");
  // A path, not a buffer: a buffer crosses the DevTools protocol first, and a
  // file big enough to show progress would stall the scene doing it.
  await session.inviter.locator("#lobby-file-input").setInputFiles(file);
  const offer = session.invitee
    .getByTestId("lobby-file-panel")
    .getByTestId("file-transfer");
  await expect(offer).toContainText(name, { timeout: 15_000 });
  await session.invitee
    .getByTestId("lobby-file-panel")
    .getByTestId("file-transfer-accept")
    .click();
}

/** Opens the channel's conference from the chat (card → tab), at its device check. */
export async function openConferenceAt(user: TestUser): Promise<Page> {
  const call = await openConference(user);
  await expect(call.getByTestId("group-call-prejoin")).toBeVisible({
    timeout: 20_000,
  });
  return call;
}

/** Joins from the device check. */
export async function joinConference(call: Page) {
  await call.getByTestId("group-call-prejoin-join").click();
  await expect(call.getByTestId("group-call-webrtc")).toBeVisible({
    timeout: 20_000,
  });
}

/** Writes a file of `mb` megabytes to send on camera, and returns its path. */
export function propFile(name: string, mb: number): string {
  const file = path.join(tmpdir(), name);
  writeFileSync(file, Buffer.alloc(mb * 1024 * 1024, 7));
  return file;
}

/** Switches a session tab's console to one of its sections. */
export async function consoleSection(
  tab: Page,
  section: "call" | "files" | "games",
) {
  await tab.getByTestId(`p2p-console-nav-${section}`).click();
  await expect(tab.getByTestId(`p2p-console-section-${section}`)).toBeVisible();
}

/** Proposes Hex Pong from the inviter's side; the invitee accepts. */
export async function startHexPong(session: Session) {
  await consoleSection(session.inviter, "games");
  await session.inviter
    .getByTestId("lobby-game-panel")
    .getByRole("button", { name: "Hex Pong" })
    .click();
  const consent = session.invitee.getByTestId("lobby-game-consent");
  await expect(consent).toBeVisible({ timeout: 15_000 });
  await consent.getByRole("button", { name: "Accept" }).click();
  for (const tab of [session.inviter, session.invitee]) {
    await expect(tab.locator("#lobby-game-canvas canvas")).toBeVisible({
      timeout: 20_000,
    });
  }
}
