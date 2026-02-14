/**
 * Onboarding state management via localStorage.
 *
 * Pure functions for reading and writing the onboarding-complete flag.
 * No DOM access — used by OnboardingHook for wiring.
 */

const STORAGE_KEY = "retro_hex_chat_onboarding_complete";

/**
 * Check whether the user has completed onboarding.
 *
 * @returns {boolean} true if onboarding was previously completed
 */
export function isOnboardingComplete() {
  return localStorage.getItem(STORAGE_KEY) === "true";
}

/**
 * Mark onboarding as complete so the wizard won't appear again.
 */
export function markOnboardingComplete() {
  localStorage.setItem(STORAGE_KEY, "true");
}
