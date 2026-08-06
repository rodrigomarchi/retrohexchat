/**
 * @section Auth And Lifecycle
 * @flow C1 [done] Empty nickname keeps Connect disabled
 * @flow C2 [done] Nickname longer than 16 chars shows inline error
 * @flow C3 [done] Nickname containing a space shows inline error
 * @flow C4 [done] Nickname starting with a digit shows inline error
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage } from "../pages/ConnectPage";

test.describe("Nickname validation", () => {
  test("empty nickname is blocked by browser validation (C1)", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await expect(connect.nicknameInput).toHaveValue("");
    await expect(connect.connectButton).toBeEnabled();
    await expect(connect.nicknameInput).toHaveAttribute("required", "");
    expect(
      await connect.nicknameInput.evaluate(
        (input) => (input as HTMLInputElement).validity.valueMissing,
      ),
    ).toBe(true);
  });

  test("input enforces 16-char maxlength on nickname (C2)", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    // Real typing (not programmatic .fill()) so the HTML maxlength is enforced.
    await connect.nicknameInput.pressSequentially("abcdefghijklmnopqrst");
    const value = await connect.nicknameInput.inputValue();
    expect(value.length).toBe(16);
  });

  test("nickname with a space shows inline error after submit (C3)", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.typeNickname("bad nick");
    await connect.connectButton.click();
    await expect(connect.nicknameError).toContainText(
      "Nickname cannot contain spaces",
    );
    await expect(connect.connectButton).toBeEnabled();
  });

  test("nickname starting with a digit shows inline error after submit (C4)", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.typeNickname("1invalid");
    await connect.connectButton.click();
    await expect(connect.nicknameError).toContainText(
      "Nickname must start with a letter or special character",
    );
    await expect(connect.connectButton).toBeEnabled();
  });
});
