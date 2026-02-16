/**
 * Notification preferences localStorage persistence for guest users.
 *
 * Registered users persist preferences server-side via UserPreferences.
 * Guests use localStorage via this module.
 */

export const STORAGE_KEY = "retro_hex_chat_notification_prefs";

/**
 * Returns default notification preferences matching the data model.
 * @returns {Object} Default notification preferences
 */
export function defaultPrefs() {
  return {
    sounds_enabled: true,
    browser_notifications: false,
    title_flash_enabled: true,
    privacy_mode: false,
    dnd_enabled: false,
    trigger_mentions: true,
    trigger_pms: true,
    trigger_channel_messages: false,
    trigger_joins_leaves: false,
    channel_levels: {},
  };
}

/**
 * Load notification preferences from localStorage.
 * Returns defaults for missing keys or corrupted data.
 * @returns {Object} Notification preferences
 */
export function loadPrefs() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return defaultPrefs();

    const stored = JSON.parse(raw);
    return { ...defaultPrefs(), ...stored };
  } catch {
    return defaultPrefs();
  }
}

/**
 * Save notification preferences to localStorage.
 * @param {Object} prefs - Notification preferences to save
 */
export function savePrefs(prefs) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
}
