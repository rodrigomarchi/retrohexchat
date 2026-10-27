/**
 * The table a one-player pointer game is laid on: lying down on a desktop's
 * window, or standing up when the page gives the canvas a box taller than
 * wide — a phone held upright — so the pieces are as big as it allows.
 *
 * A game's geometry is `{ LANDSCAPE, PORTRAIT }`, each with the `view` it
 * draws; a game of several sizes (levels) hands one geometry per id.
 *
 * @module games/core/solo/view
 */

/** Whether a view stands up. */
export const standing = (view) => view.height > view.width;

/**
 * A definition's `view`: the picture of the table the box calls for.
 * @param {object | ((gameId: string) => object)} geometry - one, or one per game id
 * @returns {(canvas: HTMLCanvasElement, gameId: string) => { width: number, height: number }}
 */
export const tableView = (geometry) => (canvas, gameId) => {
  const { LANDSCAPE, PORTRAIT } = typeof geometry === "function" ? geometry(gameId) : geometry;
  const box = canvas.getBoundingClientRect();
  return box.height > box.width ? PORTRAIT.view : LANDSCAPE.view;
};

/** The table laid for the view a game was given. */
export const laidFor = ({ LANDSCAPE, PORTRAIT }, view) => (standing(view) ? PORTRAIT : LANDSCAPE);
