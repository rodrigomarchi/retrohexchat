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

/**
 * A drawn touch for a phone's camera: a ring where a finger lands, fading as
 * it lifts. A phone has no pointer to follow, and a tap with nothing drawn is
 * as invisible on film as a click.
 *
 * Runs as an init script, in every document the camera opens.
 */
export function drawTouches(): void {
  const mount = () => {
    window.addEventListener(
      "pointerdown",
      (event) => {
        const ring = document.createElement("div");
        ring.setAttribute("aria-hidden", "true");
        Object.assign(ring.style, {
          position: "fixed",
          left: `${event.clientX - 18}px`,
          top: `${event.clientY - 18}px`,
          width: "36px",
          height: "36px",
          borderRadius: "50%",
          background: "rgba(255,255,255,0.45)",
          border: "2px solid rgba(0,0,0,0.55)",
          zIndex: "2147483647",
          pointerEvents: "none",
          transition: "opacity 450ms ease-out, transform 450ms ease-out",
        });
        document.documentElement.appendChild(ring);
        requestAnimationFrame(() =>
          requestAnimationFrame(() => {
            ring.style.opacity = "0";
            ring.style.transform = "scale(1.6)";
          }),
        );
        setTimeout(() => ring.remove(), 600);
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
