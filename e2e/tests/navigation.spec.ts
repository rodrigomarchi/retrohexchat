/**
 * @section Auth And Lifecycle
 * @flow G [done] Back button returns from register/password to nickname
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

test.describe("Connect navigation", () => {
  test("Back from :register returns to :nickname and preserves the nick (G)", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const nick = uniqueNickname();

    await connect.open();
    await connect.enterNickname(nick);
    await expect(connect.registerPasswordInput).toBeVisible();

    await connect.clickBack();
    await expect(connect.nicknameInput).toBeVisible();
    await expect(connect.nicknameInput).toHaveValue(nick);
  });
});
