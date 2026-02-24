/**
 * Pure logic for extracting browser/client information.
 * Constitution IV: hook = wiring, lib = logic.
 */

/**
 * Parse browser name and version from a User-Agent string.
 * @param {string} ua
 * @returns {string|null}
 */
export function parseBrowser(ua) {
  if (!ua) return null;

  // Order matters: check more specific patterns first
  const patterns = [
    [/OPR\/(\d+(\.\d+)?)/, "Opera"],
    [/Edg\/(\d+(\.\d+)?)/, "Edge"],
    [/Firefox\/(\d+(\.\d+)?)/, "Firefox"],
    [/(?:Chrome|CriOS)\/(\d+(\.\d+)?)/, "Chrome"],
    [/Version\/(\d+(\.\d+)?).*Safari/, "Safari"],
  ];

  for (const [regex, name] of patterns) {
    const match = ua.match(regex);
    if (match) return `${name} ${match[1]}`;
  }

  return null;
}

/**
 * Parse operating system from a User-Agent string.
 * @param {string} ua
 * @returns {string|null}
 */
export function parseOS(ua) {
  if (!ua) return null;

  // Android before Linux (Android UA contains "Linux")
  const androidMatch = ua.match(/Android (\d+(\.\d+)?)/);
  if (androidMatch) return `Android ${androidMatch[1]}`;

  // iOS
  const iosMatch = ua.match(/(?:iPhone|iPad|iPod).*OS (\d+[_.]\d+)/);
  if (iosMatch) return `iOS ${iosMatch[1].replace(/_/g, ".")}`;

  // macOS
  const macMatch = ua.match(/Mac OS X (\d+[_.]\d+([_.]\d+)?)/);
  if (macMatch) return `macOS ${macMatch[1].replace(/_/g, ".")}`;

  // Windows
  if (ua.includes("Windows NT 10.0")) {
    return ua.includes("Windows NT 10.0; Win64") && !ua.includes("Xbox")
      ? "Windows 10+"
      : "Windows 10+";
  }
  if (ua.includes("Windows NT 6.3")) return "Windows 8.1";
  if (ua.includes("Windows NT 6.2")) return "Windows 8";
  if (ua.includes("Windows NT 6.1")) return "Windows 7";
  if (ua.includes("Windows")) return "Windows";

  // Linux (after Android check)
  if (ua.includes("Linux")) return "Linux";

  // ChromeOS
  if (ua.includes("CrOS")) return "ChromeOS";

  return null;
}

/**
 * Collect all available client information from browser APIs.
 * @returns {Object}
 */
export function getClientInfo() {
  const ua = navigator.userAgent;
  return {
    browser: parseBrowser(ua),
    os: parseOS(ua),
    language: navigator.language || null,
    screen: `${screen.width}x${screen.height}`,
    color_depth: screen.colorDepth || null,
    touch: navigator.maxTouchPoints > 0,
    cores: navigator.hardwareConcurrency || null,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || null,
  };
}
