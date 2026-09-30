/**
 * @section Dialog Gallery
 * @flow DG1 [done] Every reworked dialog body opens and is photographed into e2e/screenshots/dialog-gallery for visual audit
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 *
 * This spec is the visual half of the dialog grammar work. It asserts the
 * banner is there — a dialog that lost its illustration fails here — and
 * writes a PNG per dialog so the drawing itself can be judged by eye. The
 * screenshots are build output, not fixtures: nothing compares them.
 */
import { test, expect, type Locator, type Page } from "@playwright/test";
import {
  newSignedInUser,
  uniqueChannel,
  type TestUser,
} from "../helpers/chatUsers";

const SHOTS = "screenshots/dialog-gallery";

async function shoot(page: Page, target: Locator, name: string) {
  await expect(target).toBeVisible();
  await page.waitForTimeout(350);
  await target.screenshot({ path: `${SHOTS}/${name}.png` });
}

/**
 * A banner is the contract: the dialog says what it is before it asks
 * anything. `scope` narrows where the banner is looked for — a tabbed dialog
 * keeps every panel in the DOM, so the first banner found belongs to whichever
 * tab was built first, not to the one on screen.
 */
async function shootWithBanner(
  page: Page,
  target: Locator,
  name: string,
  scope: Locator = target,
) {
  await expect(scope.locator("[data-dialog-banner]").first()).toBeVisible();
  await shoot(page, target, name);
}

test.describe("dialog gallery", () => {
  test.describe.configure({ mode: "serial" });

  let user: TestUser;
  let channel: string;

  test.beforeAll(async ({ browser }) => {
    user = await newSignedInUser(browser, "gal", "pass12345");
    channel = uniqueChannel("gallery");
    await user.chat.sendMessage(`/join ${channel}`);
    await user.page.waitForTimeout(1000);
    await user.chat.sendMessage("/topic Everything about the new dialogs");
    await user.page.waitForTimeout(400);
    await user.chat.sendMessage("/setwelcome Read the topic, then say hello.");
    await user.page.waitForTimeout(600);
  });

  test.afterAll(async () => {
    await user?.ctx.close();
  });

  test("account", async () => {
    await user.chat.openAccountRegisterFromMenu();
    await shootWithBanner(user.page, user.chat.accountDialog, "account");
    await user.page.keyboard.press("Escape");
  });

  test("profile", async () => {
    await user.chat.openAccountProfileFromMenu();
    await user.chat.profileDialog
      .getByTestId("profile-bio")
      .fill("Runs the arcade nights. Ask me about Warlords.");
    await user.page.waitForTimeout(400);
    await shootWithBanner(user.page, user.chat.profileDialog, "profile");
    await user.page.keyboard.press("Escape");
  });

  test("away", async () => {
    await user.chat.openAwayFromMenu();
    await user.chat.awayDialog
      .getByTestId("away-message")
      .fill("Gone to lunch");
    await user.chat.awayDialog.getByRole("checkbox").first().click();
    await user.chat.awayDialog
      .getByRole("button", { name: "Set Away", exact: true })
      .click();
    await user.page.waitForTimeout(600);
    await shootWithBanner(user.page, user.chat.awayDialog, "away");
    await user.page.keyboard.press("Escape");
  });

  test("user modes", async () => {
    await user.chat.openUserModesFromMenu();
    await user.chat.userModesDialog.getByRole("checkbox").first().click();
    await user.chat.userModesDialog
      .getByRole("button", { name: "Apply", exact: true })
      .click();
    await user.page.waitForTimeout(600);
    await shootWithBanner(user.page, user.chat.userModesDialog, "user-modes");
    await user.page.keyboard.press("Escape");
  });

  test("alias editor", async () => {
    await user.chat.sendMessage("/alias add wave /me waves at everybody");
    await user.page.waitForTimeout(500);
    await user.chat.openAliasEditorFromMenu();
    await shootWithBanner(user.page, user.chat.aliasDialog, "alias");
    await user.page.keyboard.press("Escape");
  });

  test("autojoin", async () => {
    await user.chat.sendMessage(`/autojoin add ${channel}`);
    await user.page.waitForTimeout(500);
    await user.chat.openAutojoinDialogFromMenu();
    await shootWithBanner(user.page, user.chat.autojoinDialog, "autojoin");
    await user.page.keyboard.press("Escape");
  });

  test("perform", async () => {
    await user.chat.sendMessage("/perform add /msg NickServ info");
    await user.page.waitForTimeout(500);
    await user.chat.openPerformDialogFromMenu();
    await shootWithBanner(user.page, user.chat.performDialog, "perform");
    await user.page.keyboard.press("Escape");
  });

  test("auto respond", async () => {
    await user.chat.openAutorespondDialogFromMenu();
    await shootWithBanner(
      user.page,
      user.chat.autorespondDialog,
      "auto-respond",
    );
    await user.page.keyboard.press("Escape");
  });

  test("timers", async () => {
    await user.chat.sendMessage("/timer nightly 3600 /me is still here");
    await user.page.waitForTimeout(500);
    await user.chat.openTimersFromToolsMenu();
    await shootWithBanner(user.page, user.chat.timersDialog, "timers");
    await user.page.keyboard.press("Escape");
  });

  test("trusted terminals", async () => {
    await user.chat.openTrustedTerminalsFromMenu();
    await shootWithBanner(
      user.page,
      user.chat.trustedTerminalsDialog,
      "trusted-terminals",
    );
    await user.page.keyboard.press("Escape");
  });

  test("channel central, every tab", async () => {
    await user.chat.openChannelCentralFromMenu();
    await shootWithBanner(
      user.page,
      user.chat.channelCentralDialog,
      "channel-central-general",
    );

    for (const tab of ["modes", "access_lists", "registration"] as const) {
      await user.chat.switchChannelCentralToTab(tab);
      await shootWithBanner(
        user.page,
        user.chat.channelCentralDialog,
        `channel-central-${tab}`,
        user.chat.channelCentralPanel(tab),
      );
    }

    await user.page.keyboard.press("Escape");
  });
});
