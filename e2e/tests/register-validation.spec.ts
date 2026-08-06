/**
 * @section Auth And Lifecycle
 * @flow E [done] Register step password mismatch shows inline error
 * @flow F [done] Register step short password shows inline error
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

test.describe("Register step validation", () => {
  test("passwords that do not match show inline error (E)", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await expect(connect.registerPasswordInput).toBeVisible();

    await connect.registerPasswordInput.fill("correct-pass");
    await connect.registerPasswordConfirmInput.fill("different-pass");
    await expect(connect.registerButton).toBeEnabled();
    await connect.registerButton.click();

    await expect(connect.registerError).toContainText("Passwords do not match");
  });

  test("password shorter than 5 chars shows inline error (F)", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());

    await connect.registerPasswordInput.fill("abc");
    await connect.registerPasswordConfirmInput.fill("abc");
    await expect(connect.registerButton).toBeEnabled();
    await connect.registerButton.click();

    await expect(connect.registerError).toContainText(
      "Password must be at least 5 characters",
    );
  });
});
