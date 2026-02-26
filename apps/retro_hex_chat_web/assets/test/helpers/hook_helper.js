/**
 * Test helper for mounting LiveView hooks in jsdom.
 *
 * Provides:
 * - mountHook(hookDef, options) — creates DOM element, mocks LiveView API, calls mounted()
 * - cleanupDOM() — clears document.body (use in afterEach)
 * - mockLocalStorage() — in-memory localStorage mock
 */

// Stub scrollIntoView — not implemented in jsdom
if (!Element.prototype.scrollIntoView) {
  Element.prototype.scrollIntoView = function () {};
}

/**
 * Mount a LiveView hook definition in a test environment.
 *
 * @param {Object} hookDef - The hook definition object (e.g. AutocompleteHook)
 * @param {Object} [options={}]
 * @param {string} [options.tag="div"] - HTML tag for the hook element
 * @param {string} [options.html=""] - Inner HTML for the element
 * @param {Object} [options.attrs={}] - Attributes to set on the element
 * @param {HTMLElement} [options.parent] - Parent element (defaults to document.body)
 * @returns {Object} hook instance with el, pushEvent, pushEventTo, and helpers
 */
export function mountHook(hookDef, options = {}) {
  const { tag = "div", html = "", attrs = {}, parent } = options;

  // Create the hook element
  const el = document.createElement(tag);
  el.innerHTML = html;
  for (const [key, value] of Object.entries(attrs)) {
    el.setAttribute(key, value);
  }

  const parentEl = parent || document.body;
  parentEl.appendChild(el);

  // Create the hook instance by binding all methods from the definition
  const hook = Object.create(hookDef);
  hook.el = el;

  // Mock LiveView API
  hook.__pushEvents = [];
  hook.pushEvent = vi.fn((event, payload) => {
    hook.__pushEvents.push({ event, payload });
  });

  hook.pushEventTo = vi.fn((target, event, payload) => {
    hook.__pushEvents.push({ target, event, payload });
  });

  // handleEvent registry
  hook.__eventHandlers = {};
  hook.handleEvent = vi.fn((event, callback) => {
    if (!hook.__eventHandlers[event]) {
      hook.__eventHandlers[event] = [];
    }
    hook.__eventHandlers[event].push(callback);
  });

  // Call mounted
  if (hook.mounted) {
    hook.mounted();
  }

  return hook;
}

/**
 * Simulate a server push event on a mounted hook.
 *
 * @param {Object} hook - The mounted hook instance
 * @param {string} event - Event name
 * @param {Object} payload - Event payload
 */
export function simulateEvent(hook, event, payload) {
  const handlers = hook.__eventHandlers[event];
  if (handlers) {
    handlers.forEach((fn) => fn(payload));
  }
}

/**
 * Get all pushEvent calls for a specific event name.
 *
 * @param {Object} hook - The mounted hook instance
 * @param {string} eventName - Event name to filter
 * @returns {Array} Array of payloads pushed for that event
 */
export function getPushEvents(hook, eventName) {
  return hook.__pushEvents.filter((e) => e.event === eventName).map((e) => e.payload);
}

/**
 * Clean up document.body after each test.
 */
export function cleanupDOM() {
  document.body.innerHTML = "";
}

/**
 * Create an in-memory localStorage mock.
 * Call this in beforeEach and restore in afterEach.
 *
 * @returns {{ store: Object, restore: Function }}
 */
export function mockLocalStorage() {
  const store = {};
  const original = globalThis.localStorage;

  const mock = {
    getItem: vi.fn((key) => store[key] ?? null),
    setItem: vi.fn((key, value) => {
      store[key] = String(value);
    }),
    removeItem: vi.fn((key) => {
      delete store[key];
    }),
    clear: vi.fn(() => {
      Object.keys(store).forEach((k) => delete store[k]);
    }),
    get length() {
      return Object.keys(store).length;
    },
    key: vi.fn((i) => Object.keys(store)[i] ?? null),
  };

  Object.defineProperty(globalThis, "localStorage", {
    value: mock,
    writable: true,
    configurable: true,
  });

  const restore = () => {
    Object.defineProperty(globalThis, "localStorage", {
      value: original,
      writable: true,
      configurable: true,
    });
    vi.restoreAllMocks();
  };

  return { store, restore };
}
