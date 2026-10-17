/**
 * Window groups — the windows of one page of the site, which open, lay out and
 * close together — and the documents the address bar follows.
 *
 * Every decision the window manager takes about them lives here, over plain
 * data it reads off its registry, so each is tested without a desktop. The
 * manager reads the DOM (which windows belong to a group, in the order the page
 * draws them) and carries out the plan; it decides nothing about groups itself.
 */

/**
 * One window of a group, as the window manager's registry knows it.
 *
 * @typedef {object} GroupMember
 * @property {string} id
 * @property {boolean} open
 * @property {boolean} minimized
 * @property {boolean} placed - laid out since the group last opened whole
 * @property {number} z - stacking order; the highest was in front last
 */

/**
 * What opening a group comes to:
 *  - `open_all`: no window of it is open, so all of them open and are laid out
 *    afresh, the first in front;
 *  - `lay_out`: some of its open windows were never placed — the page just
 *    arrived — so the open ones are laid out;
 *  - `front`: it is on the desk as the reader left it, so the window they had
 *    in front last comes forward, and the ones they closed stay closed;
 *  - `none`: a window of it is already in front, or it has no windows.
 *
 * @typedef {{kind: "open_all" | "lay_out", ids: string[]}
 *   | {kind: "front", id: string}
 *   | {kind: "none"}} GroupOpenPlan
 */

/**
 * Decides what opening a group does.
 *
 * @param {GroupMember[]} members - the group's windows, in the page's order
 * @param {string | null} focusedId - the window in front of the whole desk
 * @returns {GroupOpenPlan}
 */
export function planOpenGroup(members, focusedId) {
  if (members.length === 0) return { kind: "none" };

  const open = members.filter((member) => member.open);
  if (open.length === 0) return { kind: "open_all", ids: members.map((member) => member.id) };
  if (open.some((member) => !member.placed)) {
    return { kind: "lay_out", ids: open.map((member) => member.id) };
  }
  if (open.some((member) => member.id === focusedId)) return { kind: "none" };

  return { kind: "front", id: frontMember(open) };
}

/**
 * The window of a group the reader had in front last: the highest one.
 *
 * @param {GroupMember[]} members
 * @returns {string | null} its id, or null for no windows
 */
export function frontMember(members) {
  let front = null;
  for (const member of members) {
    if (front === null || member.z > front.z) front = member;
  }
  return front && front.id;
}

/**
 * The groups a layout is owed: any with an open window that was never placed —
 * the page in the first paint, or one a patch just put on the desk.
 *
 * @param {{group: string | null, open: boolean, placed: boolean}[]} windows
 * @returns {string[]} the groups, each once
 */
export function groupsToLayOut(windows) {
  const groups = new Set();
  for (const win of windows) {
    if (win.group && win.open && !win.placed) groups.add(win.group);
  }
  return [...groups];
}

/**
 * Whether a window starts open. A group's windows start the way the group's
 * root says, once for all of them (`data-window-group-open`) — the home a
 * visitor's chat is in front of starts closed; any other window, the way it
 * says itself (`data-window-initial-open`).
 *
 * @param {string | undefined} groupOpen - the group root's attribute, if in a group
 * @param {string | undefined} initialOpen - the window's own attribute
 * @returns {boolean}
 */
export function opensAtStart(groupOpen, initialOpen) {
  if (groupOpen !== undefined) return groupOpen !== "false";
  return initialOpen !== "false";
}

/**
 * Whether no window of a document's slot is open any more — the moment the
 * address bar has to follow whatever is in front instead.
 *
 * @param {{slot: string | null, open: boolean}[]} windows
 * @param {string} slot
 * @returns {boolean}
 */
export function lastOpenOfSlot(windows, slot) {
  return !windows.some((win) => win.slot === slot && win.open);
}
