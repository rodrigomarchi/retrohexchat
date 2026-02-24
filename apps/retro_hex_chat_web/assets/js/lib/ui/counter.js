/**
 * Character counter state computation.
 *
 * Determines the display text and visual severity for a character counter,
 * enabling the hook to simply apply the returned state to DOM elements.
 */

/**
 * Computes the character counter display state.
 *
 * @param {number} length - Current input length
 * @param {number} maxLength - Maximum allowed characters
 * @param {Object} [thresholds] - Severity thresholds
 * @param {number} [thresholds.warning=450] - Length above which "warning" severity applies
 * @param {number} [thresholds.danger=900] - Length above which "danger" severity applies
 * @returns {{ text: string, severity: "normal"|"warning"|"danger" }}
 */
export function getCounterState(length, maxLength, thresholds = {}) {
  const { warning = 450, danger = 900 } = thresholds;

  const text = length + "/" + maxLength;

  let severity = "normal";
  if (length > danger) {
    severity = "danger";
  } else if (length > warning) {
    severity = "warning";
  }

  return { text, severity };
}
