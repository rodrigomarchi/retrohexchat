/**
 * Building the floating reaction bubbles for the conference — DOM construction,
 * no channel and no timers.
 *
 * A reaction is a channel round-trip and a bubble that floats over a tile for a
 * moment; the hook owns the channel and the removal timer, and this owns the
 * element building — the emoji map, cloning a template icon, ensuring a stack
 * and assembling the bubble — so those are testable in jsdom without a call.
 *
 * @module group_call/reactions
 */

/** How long a bubble floats before the hook removes it. */
export const REACTION_TTL_MS = 2400;

/** The fallback emoji for a reaction, defaulting to a heart. */
export function reactionEmoji(reaction) {
  return (
    {
      heart: "❤️",
      thumbs_up: "👍",
      clap: "👏",
      laugh: "😄",
      wow: "✨",
    }[reaction] || "❤️"
  );
}

/**
 * Clone the SVG/HTML icon a reaction's template carries, or null when the host
 * has no template for it (the caller then falls back to an emoji).
 *
 * @param {Element|null|undefined} hostEl the element carrying the templates
 * @param {string} reaction
 * @returns {Element|null}
 */
export function reactionIconNode(hostEl, reaction) {
  const template = hostEl?.querySelector?.(
    `[data-group-call-reaction-icon-template="${reaction}"]`,
  );
  const node = template?.content?.firstElementChild?.cloneNode(true);
  const isHTMLElement = typeof HTMLElement !== "undefined" && node instanceof HTMLElement;
  const isSVGElement = typeof SVGElement !== "undefined" && node instanceof SVGElement;

  return isHTMLElement || isSVGElement ? node : null;
}

/**
 * The reaction stack on a tile, created and attached if it is not there yet.
 *
 * @param {Element} tile
 * @returns {Element}
 */
export function ensureReactionStack(tile) {
  let stack = tile.querySelector("[data-group-call-reactions]");

  if (!stack) {
    stack = document.createElement("div");
    stack.className = "group-call-reaction-stack";
    stack.dataset.groupCallReactions = "";
    tile.appendChild(stack);
  }

  return stack;
}

/**
 * Assemble a reaction bubble: the icon node when present, else the emoji.
 *
 * @param {object} params
 * @param {string} params.reaction
 * @param {string} params.reactionId
 * @param {Element|null} params.iconNode
 * @param {string} params.emoji
 * @returns {HTMLSpanElement}
 */
export function buildReactionBubble({ reaction, reactionId, iconNode, emoji }) {
  const bubble = document.createElement("span");
  bubble.className = "group-call-reaction-bubble";
  bubble.dataset.groupCallReactionBubble = "";
  bubble.dataset.reaction = reaction;
  bubble.dataset.reactionId = reactionId;

  if (iconNode) {
    bubble.appendChild(iconNode);
  } else {
    bubble.textContent = emoji;
  }

  return bubble;
}
