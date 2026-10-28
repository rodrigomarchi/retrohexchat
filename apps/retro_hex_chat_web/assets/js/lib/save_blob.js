/**
 * A file handed to the person to keep: a hidden link to the blob, clicked.
 *
 * The address the link points at is answered rather than let go here: a
 * browser still reading it when it is revoked saves nothing, so the caller
 * revokes it when the next file replaces it, or when it goes away.
 *
 * @module save_blob
 */

/**
 * Starts a download of `blob` named `name`.
 * @param {Document} doc
 * @param {Blob} blob
 * @param {string} name
 * @returns {string} the object URL, for the caller to revoke later
 */
export function saveBlob(doc, blob, name) {
  const url = doc.defaultView.URL.createObjectURL(blob);
  const link = doc.createElement("a");
  link.href = url;
  link.download = name;
  link.className = "u-hidden";
  doc.body.appendChild(link);
  link.click();
  doc.body.removeChild(link);
  return url;
}
