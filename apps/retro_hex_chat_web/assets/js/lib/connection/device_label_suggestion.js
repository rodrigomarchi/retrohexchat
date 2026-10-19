const LABEL_MAX_LENGTH = 100;

const BROWSER_NAMES = ["Firefox", "Chrome", "Safari", "Edge", "Opera"];

/**
 * Build a stable, human-readable trusted-terminal label from persisted
 * client metadata.
 *
 * @param {Object} info
 * @returns {string}
 */
export function suggestDeviceLabel(info = {}) {
  const device = deviceName(info);
  const browser = browserName(info.browser);
  return truncateLabel([device, browser].filter(Boolean).join(" ") || "Trusted Terminal");
}

function deviceName(info) {
  const os = cleanValue(info.os);
  const normalized = os.toLowerCase();

  if (normalized.startsWith("ios")) return iOSDeviceName(info);
  if (normalized.startsWith("android")) return androidDeviceName(info);
  if (normalized.startsWith("macos")) return "Mac";
  if (normalized.startsWith("windows")) return "Windows";
  if (normalized.startsWith("chromeos")) return "Chromebook";
  if (normalized.startsWith("linux")) return "Linux";
  if (info.touch === true) return "Touch Terminal";
  return os || null;
}

function iOSDeviceName(info) {
  const dimensions = parseScreen(info.screen);
  if (!dimensions) return "iOS";
  return Math.min(dimensions.width, dimensions.height) < 600 ? "iPhone" : "iPad";
}

function androidDeviceName(info) {
  const dimensions = parseScreen(info.screen);
  if (!dimensions) return "Android";
  return Math.min(dimensions.width, dimensions.height) >= 600 ? "Android Tablet" : "Android Phone";
}

function browserName(browser) {
  const value = cleanValue(browser);
  if (!value) return null;

  const name = BROWSER_NAMES.find((knownName) =>
    value.toLowerCase().startsWith(knownName.toLowerCase()),
  );

  return name || value.replace(/\s+\d+(\.\d+)*.*$/, "");
}

function parseScreen(screen) {
  const match = cleanValue(screen).match(/^(\d+)x(\d+)$/);
  if (!match) return null;

  return {
    width: Number.parseInt(match[1], 10),
    height: Number.parseInt(match[2], 10),
  };
}

function truncateLabel(label) {
  const cleanLabel = cleanValue(label).replace(/\s+/g, " ");
  if (cleanLabel.length <= LABEL_MAX_LENGTH) return cleanLabel;
  return cleanLabel.slice(0, LABEL_MAX_LENGTH).trimEnd();
}

function cleanValue(value) {
  return typeof value === "string" ? value.trim() : "";
}
