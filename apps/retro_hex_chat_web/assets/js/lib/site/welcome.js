/**
 * The Welcome window, for a visitor who has already been welcomed.
 *
 * The home's HTML is the same for everybody — a search engine and a first-time
 * visitor read the whole Welcome — but a visitor who has seen it once lands in
 * the chat: the Welcome opens minimized on the taskbar, one click away. The
 * browser remembers, and nothing about it reaches the server.
 *
 * Seen means the reader did something with it: entered the chat or asked for
 * an account from it, closed or minimized it, or left the home for another
 * address. Merely loading the page is not seeing it.
 */
import { log } from "../logger";

export const WELCOME_KEY = "rhc.welcome.seen";
export const WELCOME_WINDOW = '[data-document-page="home"]';

/**
 * Whether this browser has welcomed the visitor before. Every window starts
 * hidden until the manager places it, so minimizing right after mounting means
 * the Welcome never shows. Storage can be off; that only means welcoming again.
 */
export function welcomedBefore(storage) {
  try {
    return storage.getItem(WELCOME_KEY) !== null;
  } catch (error) {
    log.warn("[welcome] could not read whether the visitor was welcomed", error);
    return false;
  }
}

/** Remember the visitor has been welcomed. Storage can be off; that only means asking again. */
export function rememberWelcomed(storage) {
  try {
    storage.setItem(WELCOME_KEY, "1");
  } catch (error) {
    log.warn("[welcome] could not remember the visitor was welcomed", error);
  }
}

/** Whether a click is the reader acting on the Welcome window. */
export function welcomeAction(target) {
  if (!target || typeof target.closest !== "function") return false;
  if (target.closest("[data-welcome-enter]")) return true;
  return Boolean(target.closest(`${WELCOME_WINDOW} [data-window-control]`));
}

/** Whether a click is the reader entering the chat from the Welcome. */
export function enteringChat(target) {
  if (!target || typeof target.closest !== "function") return false;
  return Boolean(target.closest('[data-welcome-enter="chat"]'));
}

/** Whether a patch took the reader off the home. */
export function leftHome(href, homePaths) {
  if (!href) return false;
  const path = new URL(href, "http://desktop.invalid").pathname.replace(/\/$/, "") || "/";
  return !homePaths.includes(path);
}
