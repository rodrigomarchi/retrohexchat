import { Page, Locator, expect } from '@playwright/test';

// Page Object for the v2 ConnectLive flow at /connect.
// Mirrors the three steps in the LiveView state machine: :nickname, :register,
// :password (only one is visible at a time).
export class ConnectPage {
  readonly page: Page;
  readonly nicknameInput: Locator;
  readonly connectButton: Locator;
  readonly backButton: Locator;
  // :register step (brand-new nickname)
  readonly registerPasswordInput: Locator;
  readonly registerPasswordConfirmInput: Locator;
  readonly registerButton: Locator;
  // :password step (already-registered nickname)
  readonly authPasswordInput: Locator;
  readonly authButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.nicknameInput = page.locator('#nickname');
    this.connectButton = page.getByTestId('connect-btn');
    this.backButton = page.getByTestId('back-btn');
    this.registerPasswordInput = page.locator('#reg-password');
    this.registerPasswordConfirmInput = page.locator('#reg-password-confirm');
    this.registerButton = page.getByTestId('register-btn');
    this.authPasswordInput = page.locator('#password');
    this.authButton = page.getByTestId('auth-btn');
  }

  async open() {
    await this.page.goto('/connect');
    await expect(this.nicknameInput).toBeVisible();
  }

  async enterNickname(nick: string) {
    await this.nicknameInput.fill(nick);
    // phx-debounce=300ms on the validate event — wait for the connect button
    // to clear validation state before clicking.
    await expect(this.connectButton).toBeEnabled();
    await this.connectButton.click();
  }

  async registerWithPassword(password: string) {
    await expect(this.registerPasswordInput).toBeVisible();
    await this.registerPasswordInput.fill(password);
    await this.registerPasswordConfirmInput.fill(password);
    await expect(this.registerButton).toBeEnabled();
    await this.registerButton.click();
  }

  async authenticateWithPassword(password: string) {
    await expect(this.authPasswordInput).toBeVisible();
    await this.authPasswordInput.fill(password);
    await expect(this.authButton).toBeEnabled();
    await this.authButton.click();
  }
}

// Generates a nickname that satisfies ConnectLive validation:
//   - starts with a letter
//   - 1–16 chars
//   - no spaces
// And is unique enough to avoid collisions across runs without a DB reset.
export function uniqueNickname(prefix = 'e2e'): string {
  const rand = Math.random().toString(36).slice(2, 8);
  return `${prefix}${rand}`;
}
