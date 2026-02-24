/**
 * Favicon badge overlay.
 *
 * Draws a red dot on the existing favicon using canvas,
 * then updates the <link rel="icon"> href.
 */

/**
 * Create a favicon badge manager.
 * @returns {Object} { show, clear, isActive }
 */
export function createFaviconBadge() {
  let originalHref = null;
  let active = false;

  function getLinkEl() {
    return (
      document.querySelector('link[rel="icon"]') ||
      document.querySelector('link[rel="shortcut icon"]')
    );
  }

  function captureOriginal() {
    if (originalHref) return;
    const link = getLinkEl();
    if (link) {
      originalHref = link.href;
    }
  }

  /**
   * Show red dot badge on favicon.
   */
  function show() {
    captureOriginal();
    if (!originalHref) return;
    if (active) return;

    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => {
      const size = 32;
      const canvas = document.createElement("canvas");
      canvas.width = size;
      canvas.height = size;
      const ctx = canvas.getContext("2d");

      // Draw original favicon
      ctx.drawImage(img, 0, 0, size, size);

      // Draw red dot at bottom-right
      const dotRadius = 5;
      const dotX = size - dotRadius - 1;
      const dotY = size - dotRadius - 1;

      ctx.beginPath();
      ctx.arc(dotX, dotY, dotRadius, 0, 2 * Math.PI);
      ctx.fillStyle = "#cc0000";
      ctx.fill();
      ctx.strokeStyle = "#ffffff";
      ctx.lineWidth = 1;
      ctx.stroke();

      const link = getLinkEl();
      if (link) {
        link.href = canvas.toDataURL("image/png");
        active = true;
      }
    };

    img.onerror = () => {
      // Silently fail if favicon can't be loaded
    };

    img.src = originalHref;
  }

  /**
   * Clear badge and restore original favicon.
   */
  function clear() {
    if (!active || !originalHref) return;
    const link = getLinkEl();
    if (link) {
      link.href = originalHref;
    }
    active = false;
  }

  /**
   * Check if badge is currently active.
   * @returns {boolean}
   */
  function isActive() {
    return active;
  }

  return { show, clear, isActive };
}
