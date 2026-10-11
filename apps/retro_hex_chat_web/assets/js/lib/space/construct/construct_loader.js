/**
 * The Construct's build mode, fetched only by a page that is in one.
 *
 * Every Space loads the isometric renderer; only the Construct builds. Keeping
 * the palette, the build mode and the picking out of the Space chunk is what
 * keeps that chunk inside its budget for everyone standing on the End of Time.
 * @module space/construct/construct_loader
 */

/**
 * @param {object} options - `ConstructController` options
 * @returns {Promise<import("./construct_controller.js").ConstructController>}
 */
export function loadConstructController(options) {
  return import("./construct_controller.js").then(
    ({ ConstructController }) => new ConstructController(options),
  );
}
