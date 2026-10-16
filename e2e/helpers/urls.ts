/**
 * The addresses of the one desktop, as the address bar shows them.
 *
 * The chat has no page of its own: a member lands on the home (`/`), and the
 * address follows the channel in front (`/c/<name>`), in the reader's language
 * (`/pt-BR/c/<name>`). A private conversation never gets one, so it reads as
 * the home.
 */

/** Any address at which the chat is the window in front. */
export const CHAT_URL =
  /^https?:\/\/[^/]+\/(?:[a-z]{2}(?:-[A-Za-z]{2,4})?\/?)?(?:c\/[^/?#]+)?(?:\?.*)?$/;

/** A channel's address, from its name with or without the `#`. */
export function channelPath(channel: string, locale?: string): string {
  const name = encodeURIComponent(channel.replace(/^#/, ""));
  return `${locale ? `/${locale}` : ""}/c/${name}`;
}

/** The address bar while `channel` is the conversation in front. */
export function channelUrl(channel: string): RegExp {
  const name = encodeURIComponent(channel.replace(/^#/, "")).replace(
    /[.*+?^${}()|[\]\\]/g,
    "\\$&",
  );
  return new RegExp(`/c/${name}(?:\\?.*)?$`);
}
