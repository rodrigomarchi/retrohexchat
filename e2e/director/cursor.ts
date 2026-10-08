/**
 * A drawn pointer for the camera.
 *
 * A headless browser has no system cursor, so the screencast shows clicks and
 * pointing with nothing on screen to follow. This draws a Windows-98 arrow that
 * tracks the mouse, above everything and transparent to it: it never takes a
 * click, a hover or a layout slot from the page it is drawn on.
 *
 * Runs as an init script, in every document the camera opens.
 */
export function drawCursor(): void {
  const ARROW =
    '<svg xmlns="http://www.w3.org/2000/svg" width="12" height="19" viewBox="0 0 12 19" shape-rendering="crispEdges">' +
    '<path d="M0 0v16l4-4 3 7 2-1-3-7h6z" fill="#fff" stroke="#000" stroke-width="1"/></svg>';

  const mount = () => {
    if (document.getElementById("director-cursor")) return;
    const cursor = document.createElement("div");
    cursor.id = "director-cursor";
    cursor.setAttribute("aria-hidden", "true");
    cursor.innerHTML = ARROW;
    Object.assign(cursor.style, {
      position: "fixed",
      left: "0",
      top: "0",
      width: "12px",
      height: "19px",
      zIndex: "2147483647",
      pointerEvents: "none",
      transform: "translate(-200px, -200px)",
    });
    document.documentElement.appendChild(cursor);
    window.addEventListener(
      "mousemove",
      (event) => {
        cursor.style.transform = `translate(${event.clientX}px, ${event.clientY}px)`;
      },
      { capture: true, passive: true },
    );
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mount, { once: true });
  } else {
    mount();
  }
}
