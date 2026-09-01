import { Browser, expect, Page } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
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
 * Two acts, because that is what the product does now. The control creates the
 * room and writes its card into the channel only while the channel has no room;
 * once one exists the same control is an anchor into it, so the first click may
 * be a creation and the second is always a navigation. Following it opens a
 * real second tab — the page is returned so a spec drives the call where the
 * call actually is, and the chat stays the chat.
 */
export async function openConference(user: GroupCallUser): Promise<Page> {
  // The way *in*, specifically: a tab of this call that is on its way out
  // still colours the entry as "in another tab" until the registry catches up,
  // and clicking that shape would navigate the chat instead of opening a tab.
  const control = user.page.getByTestId("group-call-open");
  await expect(control).toBeVisible({ timeout: 20_000 });
  await expect(control).toBeEnabled();

  if ((await control.getAttribute("href")) === null) {
    await control.click();
    await expect(control).toHaveAttribute("href", /\/call\//);
  }

  const [call] = await Promise.all([
    user.ctx.waitForEvent("page"),
    control.click(),
  ]);

  await call.waitForLoadState("domcontentloaded");
  await expect(call.getByTestId("group-call-window")).toBeVisible();

  return call;
}

/**
 * The room's own address, read from whichever shape the chat is drawing.
 *
 * The entry has two of them and the difference is the point: a way *in* while
 * this person has no tab of the call, and a way *to that tab* once they do.
 * Both carry the same href, so asking for the address must not care which one
 * is on screen — a helper that only knew the first shape timed out the moment
 * the test did the very thing it was testing.
 */
export async function conferenceAddress(user: GroupCallUser): Promise<string> {
  const entry = user.page
    .getByTestId("group-call-open")
    .or(user.page.getByTestId("group-call-elsewhere"));

  await expect(entry).toHaveAttribute("href", /\/call\//);

  return (await entry.getAttribute("href")) as string;
}
