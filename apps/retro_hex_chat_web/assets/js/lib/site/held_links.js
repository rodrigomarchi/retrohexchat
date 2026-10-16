/**
 * A link of the one desktop clicked while the chat is still starting.
 *
 * The first touch of a page starts the LiveSocket, and the click that follows
 * it lands while the view is still joining. A patch link (`data-phx-link`)
 * handed to LiveView then is lost — it navigates the whole page back to where
 * it was — and handed to the browser it reloads the desktop. So it is held,
 * and followed as a patch once the view has joined.
 */

/** The address a click on a patch link should be held for, or null to let it through. */
export function heldLinkHref(event, liveState) {
  if (liveState === "ready") return null;
  if (event.defaultPrevented || event.button !== 0) return null;
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return null;

  const target = event.target;
  if (!target || typeof target.closest !== "function") return null;

  const link = target.closest("a[data-phx-link]");
  if (!link || link.target === "_blank") return null;

  return link.getAttribute("href");
}

/** The link to follow for a held address, once the desktop has redrawn it. */
export function linkFor(doc, href) {
  if (!href) return null;
  return (
    Array.from(doc.querySelectorAll("a[data-phx-link]")).find(
      (link) => link.getAttribute("href") === href,
    ) || null
  );
}
