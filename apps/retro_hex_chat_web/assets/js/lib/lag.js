export const PING_INTERVAL = 30000;
export const PING_TIMEOUT = 10000;

export function calculateLag(clientTime, now) {
  return now - clientTime;
}

export function classifyLag(ms) {
  if (ms === null || ms === undefined) return "timeout";
  if (ms < 200) return "normal";
  if (ms < 500) return "warning";
  return "critical";
}
