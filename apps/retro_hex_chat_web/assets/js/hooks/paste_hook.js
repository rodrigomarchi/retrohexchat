/**
 * LiveView hook for intercepting multi-line paste into chat input.
 * If pasted text has 2+ non-empty lines, prevents default and pushes event.
 */
const PasteHook = {
  mounted() {
    const input = document.getElementById("chat-input");
    if (!input) return;

    input.addEventListener("paste", (e) => {
      const text = (e.clipboardData || window.clipboardData).getData("text/plain");
      const lines = text.split("\n").filter((l) => l.trim().length > 0);

      if (lines.length >= 2) {
        e.preventDefault();
        this.pushEvent("paste_lines", { lines });
      }
      // Single line: allow normal paste behavior
    });
  },
};

export default PasteHook;
