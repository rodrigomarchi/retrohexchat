/**
 * @file Asking another tab of this app to come to the front.
 *
 * The server already knows what a person has open — `RetroHexChat.Surfaces`
 * monitors every surface process — so *whether* a tab exists is never asked
 * here. That answer survives `noopener`, survives two machines, and is the same
 * fact the channel-membership rule already depends on.
 *
 * What the browser can add is the one thing the server cannot do: bring an
 * existing tab forward. `BroadcastChannel` is the only way left to reach it,
 * because every surface in this product is opened with `rel="noopener"` and
 * there is deliberately no `window.opener` to call.
 *
 * **Focusing is the bonus; degrading is the requirement.** `window.focus()`
 * from a background tab is refused by most browsers most of the time, and it
 * fails silently — it returns nothing and nothing moves. So a request is a
 * question with a deadline: the tab that has the address answers only *after*
 * trying, and a request nobody answers in time resolves as `false` rather than
 * hanging. The caller then says "you already have this open" and offers the
 * link, which is the right thing to say regardless: the tab may be on another
 * monitor, in another window, or on the laptop in the other room.
 */

/** The one channel name, so a typo cannot make two half-working registries. */
export const CHANNEL_NAME = "retrohex:surfaces";

/** How long a focus request waits before it is treated as unanswered. */
export const FOCUS_TIMEOUT_MS = 300;

const FOCUS_REQUEST = "surface:focus";
const FOCUS_GRANTED = "surface:focused";

/**
 * Whether this browser can talk between tabs at all.
 *
 * Older Safari has no `BroadcastChannel`; there the answer is simply "no tab
 * answered", which is a state the caller already has to handle.
 *
 * @param {object} [scope] - Window-like object, injected in tests.
 * @returns {boolean} True when a channel can be opened.
 */
export function supported(scope = globalThis) {
  return typeof scope.BroadcastChannel === "function";
}

/**
 * Open the shared channel, or `null` where there is none.
 *
 * @param {object} [scope] - Window-like object, injected in tests.
 * @returns {BroadcastChannel|null} The channel, or null when unsupported.
 */
export function openChannel(scope = globalThis) {
  if (!supported(scope)) return null;
  return new scope.BroadcastChannel(CHANNEL_NAME);
}

/**
 * Ask whichever tab holds `path` to come to the front.
 *
 * Resolves `true` only when a tab actually answered, which it does after
 * calling `focus()` — never on the strength of having sent the question.
 *
 * @param {BroadcastChannel|null} channel - The shared channel, or null.
 * @param {string} path - The address of the tab being asked for.
 * @param {object} [options] - `timeoutMs` and `scope`, injected in tests.
 * @returns {Promise<boolean>} Whether a tab answered in time.
 */
export function requestFocus(channel, path, options = {}) {
  const { timeoutMs = FOCUS_TIMEOUT_MS, scope = globalThis } = options;

  if (!channel || !path) return Promise.resolve(false);

  return new Promise((resolve) => {
    let settled = false;

    const finish = (answered) => {
      if (settled) return;
      settled = true;
      channel.removeEventListener("message", onMessage);
      scope.clearTimeout(timer);
      resolve(answered);
    };

    const onMessage = (event) => {
      const message = event && event.data;
      if (!message || message.type !== FOCUS_GRANTED) return;
      if (message.path !== path) return;
      finish(true);
    };

    const timer = scope.setTimeout(() => finish(false), timeoutMs);

    channel.addEventListener("message", onMessage);
    channel.postMessage({ type: FOCUS_REQUEST, path });
  });
}

/**
 * Answer focus requests aimed at `path` for as long as this tab is open.
 *
 * The answer is sent *after* `focus()` has been attempted, and it means "a tab
 * with this address is here and tried", never "it worked" — no browser tells us
 * whether it worked. That is honest enough for the caller's purpose: a tab that
 * exists is a tab the person should be pointed at rather than duplicated.
 *
 * @param {BroadcastChannel|null} channel - The shared channel, or null.
 * @param {string} path - The address this tab is showing.
 * @param {object} [options] - `focus` and `onError`, injected in tests.
 * @returns {() => void} Stop answering.
 */
export function answerFocusRequests(channel, path, options = {}) {
  const { focus = () => globalThis.focus(), onError = () => {} } = options;

  if (!channel || !path) return () => {};

  const onMessage = (event) => {
    const message = event && event.data;
    if (!message || message.type !== FOCUS_REQUEST) return;
    if (message.path !== path) return;

    try {
      focus();
    } catch (error) {
      // Refused focus is the expected case, not an exception to hide: the
      // caller still has to be told a tab is here, so the answer is sent
      // either way and the reason is logged.
      onError(error);
    }

    channel.postMessage({ type: FOCUS_GRANTED, path });
  };

  channel.addEventListener("message", onMessage);
  return () => channel.removeEventListener("message", onMessage);
}
