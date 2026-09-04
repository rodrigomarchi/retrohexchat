import { Browser, expect, Page } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { enterThroughNewCard } from "./surfaceEntry";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { closeUsers, TestUser } from "./chatUsers";
import { installSyntheticMedia } from "./syntheticMedia";

export type GroupCallUser = TestUser;

export async function newGroupCallUser(
  browser: Browser,
  prefix = "gcu",
): Promise<GroupCallUser> {
  const ctx = await browser.newContext({
    permissions: ["microphone", "camera"],
  });

  await installSyntheticMedia(ctx);

  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  const password = "pass12345";

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, connect, ctx, page, nick, password };
}

export async function closeGroupCallUsers(users: GroupCallUser[]) {
  await closeUsers(users);
}

/**
 * Open a conference from the chat and land in the tab that holds it.
 *
 * Two acts, and neither of them is the control going anywhere. Pressing it
 * opens the room if there is none and writes the room's card into the channel;
 * the card is the door, and following it opens a real second tab. The page is
 * returned so a spec drives the call where the call actually is, and the chat
 * stays the chat.
 */
export async function openConference(user: GroupCallUser): Promise<Page> {
  const control = user.page.getByTestId("group-call-open");
  await expect(control).toBeVisible({ timeout: 20_000 });
  await expect(control).toBeEnabled();

  const call = await enterThroughNewCard(
    user.page,
    user.ctx,
    "group-call-open",
  );
  await expect(call.getByTestId("group-call-window")).toBeVisible();

  return call;
}

/**
 * The room's own address, read from a tab that is standing in it.
 *
 * The chat holds no address any more — the entry beside the tabs is a control
 * and the card points at the public `/join/` door — so the one place the real
 * `/call/:token` is written down is the call's own URL.
 */
export function conferenceAddress(call: Page): string {
  return new URL(call.url()).pathname;
}
