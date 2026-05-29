/**
 * Search and highlighting logic.
 *
 * Extracted from: search_highlight_hook.js
 */

/**
 * Escape special regex characters.
 *
 * @param {string} str
 * @returns {string}
 */
export function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Compile a search pattern into a RegExp.
 *
 * @param {string} query
 * @param {boolean} caseSensitive
 * @param {boolean} isRegex
 * @returns {RegExp | null} - null if invalid regex
 */
export function compilePattern(query, caseSensitive, isRegex) {
  try {
    const flags = caseSensitive ? "g" : "gi";
    return isRegex ? new RegExp(query, flags) : new RegExp(escapeRegex(query), flags);
  } catch {
    return null;
  }
}

/**
 * Highlight text matches within a DOM element.
 *
 * Finds text nodes, wraps matches in <mark class="search-highlight">.
 *
 * @param {HTMLElement} element
 * @param {RegExp} pattern
 * @returns {number} Total match count
 */
export function highlightInElement(element, pattern) {
  const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null);
  const textNodes = [];

  let node;
  while ((node = walker.nextNode())) {
    if (node.parentElement && node.parentElement.closest("mark.search-highlight")) continue;
    textNodes.push(node);
  }

  let count = 0;
  textNodes.forEach((textNode) => {
    const text = textNode.textContent;
    if (!text) return;

    pattern.lastIndex = 0;
    const matches = [];
    let match;

    while ((match = pattern.exec(text)) !== null) {
      matches.push({ start: match.index, end: match.index + match[0].length, text: match[0] });
      if (match[0].length === 0) {
        pattern.lastIndex++;
      }
    }

    if (matches.length === 0) return;

    const fragment = document.createDocumentFragment();
    let lastIdx = 0;

    matches.forEach((m) => {
      if (m.start > lastIdx) {
        fragment.appendChild(document.createTextNode(text.slice(lastIdx, m.start)));
      }
      const mark = document.createElement("mark");
      mark.className = "search-highlight";
      mark.textContent = m.text;
      fragment.appendChild(mark);
      lastIdx = m.end;
      count++;
    });

    if (lastIdx < text.length) {
      fragment.appendChild(document.createTextNode(text.slice(lastIdx)));
    }

    textNode.parentNode.replaceChild(fragment, textNode);
  });

  return count;
}

/**
 * Remove all search highlights from a container.
 *
 * @param {HTMLElement|Document} container - defaults to document
 */
export function clearHighlights(container) {
  const root = container || document;
  const marks = root.querySelectorAll("mark.search-highlight");
  marks.forEach((mark) => {
    const parent = mark.parentNode;
    const text = document.createTextNode(mark.textContent);
    parent.replaceChild(text, mark);
    parent.normalize();
  });
}

/**
 * Scroll to a specific match by index (1-based).
 *
 * @param {NodeList|Array} marks - Collection of mark elements
 * @param {number} index - 1-based index
 */
export function scrollToMatch(marks, index) {
  if (marks.length === 0) return;

  marks.forEach((m) => m.classList.remove("search-highlight-active"));

  const clampedIndex = Math.max(1, Math.min(index, marks.length));
  const target = marks[clampedIndex - 1];

  if (target) {
    target.classList.add("search-highlight-active");
    const row = target.closest("[data-message-id]");
    (row || target).scrollIntoView({ block: "center", behavior: "smooth" });
  }
}
